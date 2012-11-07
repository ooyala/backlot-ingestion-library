ENTITY_MAP =
  "&": "&amp;"
  "<": "&lt;"
  ">": "&gt;"
  '"': "&quot;"
  "'": "&#39;"
  "/": "&#x2F;"

class window.SampleDriver
  @init: =>
    $("#myfile").change(@handleFileSelect)
    @ooyalaUploader = new OoyalaUploader
      embedCodeReady: @embedCodeReady
      uploadProgress: @uploadProgress
      uploadComplete: @uploadComplete
      uploadError: @uploadError

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

  @embedCodeReady: (assetId) =>
    @display("#{assetId}: Ready")

  @uploadProgress: (assetId, progressPercent) =>
    @display("#{assetId}: Progress #{progressPercent}%")

  @uploadComplete: (assetId) =>
    @display("#{assetId}: Completed")

  ###
  The received errorHash has the following parameters:
    assetId, type, fileName, statusCode, message
  ###
  @uploadError: (errorHash) =>
    @display("#{errorHash.fileName} upload failed with status #{errorHash.statusCode}. #{errorHash.message}")
