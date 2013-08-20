CHUNK_SIZE = 1024 * 1024 * 5 # 5MB
RETRY_INTERVAL = 1000 # 1 sec

class window.OoyalaUploader
  constructor: (options={})->
    @chunkProgress = {}
    @eventListeners = {}
    @initializeListeners(options)
    @uploaderType = options?.uploaderType ? "HTML5"
    throw "uploaderType must be either HTML5 or Flash" unless @uploaderType in ["Flash", "HTML5"]
    if @uploaderType is "Flash"
      unless options?.swfUploader?
        throw new Error("a reference to the SWFUpload object is required for Flash uploads")
      @swfUploader = options.swfUploader

  initializeListeners: (options) ->
    for eventType in ["embedCodeReady", "uploadProgress", "uploadComplete", "uploadError"]
      if options[eventType]?
        listeners = if options[eventType] instanceof Array then options[eventType] else [options[eventType]]
      else
        listeners = []
      @eventListeners[eventType] = listeners

  on: (eventType, eventListener) =>
    throw new Error("invalid eventType") unless @eventListeners[eventType]?
    @eventListeners[eventType].push(eventListener)

  off: (eventType, eventListener=null) =>
    unless eventListener?
      @eventListeners[eventType] = []
      return
    listeners = @eventListeners[eventType]

    while (index = listeners.indexOf(eventListener)) >= 0
      listeners.splice(index, 1)

  uploadFile: (file, options={}) =>
    return false unless @html5UploadSupported
    movieUploader = new MovieUploader
      embedCodeReady: @embedCodeReady
      uploadProgress: @uploadProgress
      uploadComplete: @uploadComplete
      uploadError: @uploadError
      uploaderType: @uploaderType
    movieUploader.uploadFile(file, options)
    true

  embedCodeReady: (assetID) =>
    for eventListener in (@eventListeners["embedCodeReady"] ? [])
      eventListener(assetID)

  uploadProgress: (assetID, progressPercent) =>
    previousProgress = @chunkProgress[assetID]
    return if progressPercent is previousProgress
    @chunkProgress[assetID] = progressPercent
    for eventListener in (@eventListeners["uploadProgress"] ? [])
      eventListener(assetID, progressPercent)

  uploadComplete: (assetID) =>
    delete @chunkProgress[assetID]
    for eventListener in (@eventListeners["uploadComplete"] ? [])
      eventListener(assetID)

  uploadError: (assetID, type, fileName, statusCode, message) =>
    for eventListener in (@eventListeners["uploadError"] ? [])
      eventListener(assetID, type, fileName, statusCode, message)

  uploadFileUsingFlash: (options={}) =>
    throw new Error("uploaderType must be Flash to call this method") unless @uploaderType is "Flash"
    movieUploader = new MovieUploader
      embedCodeReady: @embedCodeReady
      uploadProgress: @uploadProgress
      uploadComplete: @uploadComplete
      uploadError: @uploadError
      uploaderType: @uploaderType
      swfUploader: @swfUploader
    movieUploader.uploadFileUsingFlash(options)
    true

  html5UploadSupported: FileReader?

class MovieUploader
  constructor: (options) ->
    @embedCodeReadyCallback = options?.embedCodeReady ? ->
    @uploadProgressCallback = options?.uploadProgress ? ->
    @uploadCompleteCallback = options?.uploadComplete ? ->
    @uploadErrorCallback = options?.uploadError ? ->
    @uploaderType = options?.uploaderType ? "HTML5"
    @swfUploader = options.swfUploader if @uploaderType is "Flash"
    @chunkUploaders = {}
    @completedChunkIndexes = []
    @completedChunks = 0
    @totalChunks

  ###
  Placeholders in the urls are replaced dynamically when the http request is built
  assetID   -   is replaced with the actual id of the asset (embed code)
  paths      -   is replaced with a comma separated list of labels, the ones that will be created
  ###
  uploadFile: (@file, options) =>
    console.log("Uploading file using browser: #{navigator.userAgent}")
    @setAssetMetadata(options)
    @assetMetadata.assetName ?= @file.name
    @assetMetadata.fileSize = @file.size
    @assetMetadata.fileName = @file.name
    @createAsset()

  uploadFileUsingFlash: (options) =>
    file = @swfUploader.getFile(0)
    throw new Error("Flash Upload: No Files Queued") unless file?
    @setAssetMetadata(options)
    @assetMetadata.assetName ?= file.name
    @assetMetadata.fileSize = file.size
    @assetMetadata.fileName = file.name
    @swfUploader.settings["upload_success_handler"] = @onFlashUploadComplete
    @swfUploader.settings["upload_progress_handler"] = @onFlashUploadProgress
    @swfUploader.settings["upload_error_handler"] = @onFlashUploadError
    @createAsset()

  setAssetMetadata: (options) =>
    @assetMetadata =
      assetCreationUrl: options.assetCreationUrl ? "/v2/assets"
      assetUploadingUrl: options.assetUploadingUrl ? "/v2/assets/assetID/uploading_urls"
      assetStatusUpdateUrl: options.assetStatusUpdateUrl ? "/v2/assets/assetID/upload_status"
      assetName: options.name
      assetDescription : options.description ? ""
      assetType: options.assetType ? "video"
      createdAt: new Date().getTime()
      assetLabels: options.labels ? []
      postProcessingStatus: options.postProcessingStatus ? "live"
      labelCreationUrl: options.labelCreationUrl ? "/v2/labels/by_full_path/paths"
      labelAssignmentUrl: options.labelAssignmentUrl ? "/v2/assets/assetID/labels"
      assetID: ""

  createAsset: =>
    postData =
      name: @assetMetadata.assetName
      description: @assetMetadata.assetDescription
      file_name: @assetMetadata.fileName
      file_size: @assetMetadata.fileSize
      asset_type: @assetMetadata.assetType
      post_processing_status: @assetMetadata.postProcessingStatus
    postData.chunk_size = CHUNK_SIZE if @uploaderType is "HTML5"

    jQuery.ajax
      url: @assetMetadata.assetCreationUrl
      type: "POST"
      data: postData
      success: (response) => @onAssetCreated(response)
      error: (response) => @onError(response, "Asset creation error")

  onAssetCreated: (assetCreationResponse) =>
    parsedResponse = JSON.parse(assetCreationResponse)
    @assetMetadata.assetID = parsedResponse.embed_code
    ###
    Note: It could take some time for the asset to be copied. Send the upload ready callback
    immediately so that the user has some UI indication that upload has started
    ###
    @embedCodeReadyCallback(@assetMetadata.assetID)
    @assetMetadata.assetLabels.filter (arrayElement) -> arrayElement
    @createLabels() unless @assetMetadata.assetLabels.length is 0
    @getUploadingUrls()

  createLabels: ->
    listOfLabels = @assetMetadata.assetLabels.join(",")
    jQuery.ajax
      url: @assetMetadata.labelCreationUrl.replace("paths", listOfLabels)
      type: "POST"
      success: (response) => @assignLabels(response)
      error: (response) => @onError(response, "Label creation error")

  assignLabels: (responseCreationLabels) ->
    parsedLabelsResponse = JSON.parse(responseCreationLabels)
    labelIds = (label["id"] for label in parsedLabelsResponse)
    jQuery.ajax
      url: @assetMetadata.labelAssignmentUrl.replace("assetID", @assetMetadata.assetID)
      type: "POST"
      data: JSON.stringify(labelIds)
      success: (response) => @onLabelsAssigned(response)
      error: (response) => @onError(response, "Label assignment error")

  onLabelsAssigned: (responseAssignLabels) ->
    console.log("Creation and assignment of labels complete #{@assetMetadata.assetLabels}")

  getUploadingUrls: ->
    jQuery.ajax
      url: @assetMetadata.assetUploadingUrl.split("assetID").join(@assetMetadata.assetID)
      data:
        asset_id: @assetMetadata.assetID
      success: (response) =>
        @onUploadUrlsReceived(response)
      error: (response) =>
        @onError(response, "Error getting the uploading urls")

  ###
  Uploading all chunks
  ###
  onUploadUrlsReceived: (uploadingUrlsResponse) =>
    parsedUploadingUrl = JSON.parse(uploadingUrlsResponse)
    @totalChunks = parsedUploadingUrl.length
    if @uploaderType is "HTML5"
      @startHTML5Upload(parsedUploadingUrl)
    else
      @startFlashUpload(parsedUploadingUrl)

  startHTML5Upload: (parsedUploadingUrl) =>
    chunks = new FileSplitter(@file, CHUNK_SIZE).getChunks()
    if chunks.length isnt @totalChunks
      console.log("Sliced chunks (#{chunks.length}) and uploadingUrls (#{@totalChunks}) disagree.")
    jQuery.each(chunks, (index, chunk) =>
      return if index in @completedChunkIndexes
      chunkUploader = new ChunkUploader
        assetMetadata: @assetMetadata
        chunkIndex: index
        chunk: chunk
        uploadUrl: parsedUploadingUrl[index]
        progress: @onChunkProgress
        completed: @onChunkComplete
        error: @uploadErrorCallback
      @chunkUploaders[index] = chunkUploader
      chunkUploader.startUpload()
    )

  startFlashUpload: (parsedUploadingUrl) =>
    @swfUploader.setUploadURL(parsedUploadingUrl[0])
    @swfUploader.startUpload()

  onFlashUploadProgress: (file, completedBytes, totalBytes) =>
    uploadedPercent = Math.floor((completedBytes * 100) / totalBytes)
    uploadedPercent = Math.min(100, uploadedPercent)
    @uploadProgressCallback(@assetMetadata.assetID, uploadedPercent)

  onFlashUploadComplete: (file, serverData, receivedResponse) =>
    @onAssetUploadComplete()

  onFlashUploadError: (file, errorCode, errorMessage) =>
    @uploadErrorCallback
      assetID:     @assetMetadata.assetID
      type:         @assetMetadata.assetType
      fileName:     @assetMetadata.assetName
      statusCode:   errorCode
      message:      errorMessage

  progressPercent: ->
    bytesUploadedByInProgressChunks = 0
    for chunkIndex, chunkUploader of @chunkUploaders
      bytesUploadedByInProgressChunks += chunkUploader.bytesUploaded
    bytesUploaded = (@completedChunks * CHUNK_SIZE) + bytesUploadedByInProgressChunks
    uploadedPercent = Math.floor((bytesUploaded * 100) / @assetMetadata.fileSize)
    ### uploadedPercent can be more than 100 since the last chunk may be less than CHUNK_SIZE ###
    Math.min(100, uploadedPercent)

  onChunkProgress: =>
    @uploadProgressCallback(@assetMetadata.assetID, @progressPercent())

  onChunkComplete: (event, chunkIndex) =>
    @completedChunks++
    @completedChunkIndexes.push(chunkIndex)
    delete @chunkUploaders[chunkIndex]
    @onChunkProgress()
    @onAssetUploadComplete() if @completedChunks is @totalChunks

  onAssetUploadComplete: =>
    jQuery.ajax
      url: @assetMetadata.assetStatusUpdateUrl.split("assetID").join(@assetMetadata.assetID)
      data:
        asset_id: @assetMetadata.assetID
        status: "uploaded"
      type: "PUT"
      success: (data) =>
        @uploadCompleteCallback(@assetMetadata.assetID)
      error: (response) =>
        @onError(response, "Setting asset status as uploaded error")

  onError: (response, clientMessage) =>
    try
      parsedResponse = JSON.parse(response.responseText)
      errorMessage = parsedResponse["message"]
    catch _
      errorMessage = response.statusText

    console.log("#{@assetMetadata.assetName}: #{clientMessage} with status #{response.status}: #{errorMessage}")
    @uploadErrorCallback
      assetID:     @assetMetadata.assetID
      type:         @assetMetadata.assetType
      fileName:     @assetMetadata.assetName
      statusCode:   response.status
      message:      "#{clientMessage}, #{errorMessage}"

class ChunkUploader
  constructor: (options) ->
    @assetMetadata = options.assetMetadata
    @chunk = options.chunk
    @chunkIndex = options.chunkIndex
    @progressHandler = options.progress
    @completedHandler = options.completed
    @uploadErrorCallback = options.error
    @uploadUrl = options.uploadUrl
    @bytesUploaded = 0

  startUpload: =>
    console.log("#{@assetMetadata.assetID}: Starting upload of chunk #{@chunkIndex}")
    @xhr = new XMLHttpRequest()
    @xhr.upload.addEventListener("progress", (event) =>
      @bytesUploaded = event.loaded
      @progressHandler()
    )
    @xhr.addEventListener("load", @onXhrLoad)
    @xhr.addEventListener("error", @onXhrError)
    @xhr.open("PUT", @uploadUrl)
    @xhr.send(@chunk)

  onXhrLoad: (xhr) =>
    status = xhr.target.status
    if status >= 400
      onXhrError(xhr)
    else
      @bytesUploaded = CHUNK_SIZE
      @completedHandler(xhr, @chunkIndex)

  ###
  The XHR error event is only fired if there's a failure at the network level. For application errors
  (e.g. The request returns a 404), the browser fires an onload event
  ###
  onXhrError: (xhr) =>
    status = xhr.target.status
    console.log("#{@assetMetadata.assetID}: chunk #{@chunkIndex}: Xhr Error Status #{status}")
    @uploadErrorCallback
      assetID:     @assetMetadata.assetID
      type:         @assetMetadata.assetType
      fileName:     @assetMetadata.assetName
      statusCode:   xhr.status
      message:      xhr.responseText

class FileSplitter
  constructor: (@file, @chunkSize) ->

  ###
  Splits the file into several pieces according to CHUNK_SIZE. Returns an array of chunks.
  ###
  getChunks: ->
    return [@file] unless @file.slice or @file.mozSlice
    @slice(i * @chunkSize, (i + 1) * @chunkSize) for i in [0...Math.ceil(@file.size/@chunkSize)]

  ###
  Gets a slice of the file. For example: consider a file of 100 bytes, slice(0,50) will give the first half
  of the file
  - start: index of the start byte
  - stop: index of the byte where the split should stop. If the stop is larger than the file size, stop will
  be the last byte.
  ###
  slice: (start, stop) ->
    if @file.slice
      @file.slice(start, stop)
    else if @file.mozSlice
      @file.mozSlice(start, stop)

`
/**
 * Array.filter polyfil for IE8.
 *
 * https://gist.github.com/eliperelman/1031656
 */
[].filter || (Array.prototype.filter = // Use the native array filter method, if available.
  function(a, //a function to test each value of the array against. Truthy values will be put into the new array and falsy values will
    b, // placeholder
    c, // placeholder
    d, // placeholder
    e // placeholder
  ) {
      c = this; // cache the array
      d = []; // array to hold the new values which match the expression
      for (e in c) // for each value in the array,
        ~~e + '' == e && e >= 0 && // coerce the array position and if valid,
        a.call(b, c[e], +e, c) && // pass the current value into the expression and if truthy,
        d.push(c[e]); // add it to the new array

      return d // give back the new array
  })`
