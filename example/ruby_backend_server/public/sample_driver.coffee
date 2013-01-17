ENTITY_MAP =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  '"': "&quot;"
  "'": "&#39;"
  "/": "&#x2F;"

class window.SampleDriver
  ###
  Switch between the HTML5 Upload and Flash Upload based on browser capability
  ###
  @init: =>
    if FileReader?
      $("#flashInputButton").hide()
      $("#html5InputFile").change(@handleFileSelect)
      @ooyalaUploader = new OoyalaUploader
        embedCodeReady: @embedCodeReady
        uploadProgress: @uploadProgress
        uploadComplete: @uploadComplete
        uploadError: @uploadError
        uploaderType: "HTML5"
    else
      $("#html5InputFile").hide()
      @initSWFUploader()
      @ooyalaUploader = new OoyalaUploader
        embedCodeReady: @embedCodeReady
        uploadProgress: @uploadProgress
        uploadComplete: @uploadComplete
        uploadError: @uploadError
        uploaderType: "Flash"
        swfUploader: @swfUploader

  @initSWFUploader: =>
    @swfUploader = new SWFUpload
      file_queue_limit: 1
      file_upload_limit: 1
      file_dialog_complete_handler: @handleFlashFileSelect
      flash_url: "http://localhost:7081/swfupload.swf"
      button_placeholder_id: "flashInputButton"
      button_image_url : "XPButtonUploadText_61x22.png"
      button_height: 22
      button_width: 61

  @display: (message) =>
    $("#messages").append("<div>#{@escapeHTML(message)}</div>")
    @scrollMessagesToBottom()

  @scrollMessagesToBottom: =>
    messages = $("#messages")
    scrollTop = messages[0].scrollHeight - messages.outerHeight() - 1
    messages.prop(scrollTop: scrollTop)

  @escapeHTML: (text) =>
    String(text).replace(/[&<>"'\/]/g, (character) -> ENTITY_MAP[character])

  @handleFileSelect: (event) =>
    file = event.target.files[0]
    options = labels: $("#labelsText").val().split("\n")
    @display("Browser does not support HTML5 file uploads") unless @ooyalaUploader.uploadFile(file, options)

  @handleFlashFileSelect: (numFilesSelected, numFilesQueued, numFilesInQueue) =>
    options = labels: $("#labelsText").val().split("\n")
    @ooyalaUploader.uploadFileUsingFlash(options)

  @embedCodeReady: (assetID) =>
    @display("#{assetID}: Ready")

  @uploadProgress: (assetID, progressPercent) =>
    @display("#{assetID}: Progress #{progressPercent}%")

  @uploadComplete: (assetID) =>
    @display("#{assetID}: Completed")

  ###
  The received errorHash has the following parameters:
    assetID, type, fileName, statusCode, message
  ###
  @uploadError: (errorHash) =>
    @display("#{errorHash.fileName} upload failed with status #{errorHash.statusCode}. #{errorHash.message}")
