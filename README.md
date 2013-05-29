# Ooyala Backlot Uploader JavaScript Library v2

## Overview

The Ooyala Backlot Uploader JavaScript library is an easy way to integrate with Ooyala's ingestion application
programming interface (API). It supports two ways to upload video files:

* Chunked upload using the HTML5 APIs

    By default, it uses the HTML5 File API to chunk a file in the client and upload the chunks to Ooyala's
    servers. This requires a browser that supports the File APIs. Supported browsers are Firefox 15+, Chrome
    22+, Safari 6+, and IE with the ChromeFrame plugin.
    This is the recommended approach, particularly for large files, since a failed request only involves
    retrying that chunk rather than the entire file. It also boosts upload speed since multiple chunks can be
    uploaded in parallel.

* Single-chunk upload using a Flash SWF

    For older browsers that do not support the File API, the library uses a Flash swf from the
    [swfUpload](http://code.google.com/p/swfupload/) library to upload the file in a single chunk.
    The library supports browsers with Flash version 9 or greater.

## Reference

This document assumes familiarity with the Ooyala V2 APIs. Refer to
http://support.ooyala.com/developers/documentation/ and http://api.ooyala.com/docs/v2 for descriptions of the
Ooyala API URIs that underly the Backlot Uploader JavaScript Library.

## Architecture: Signing Server

With version 2 of the Backlot API, every request must be signed with a user's secret. Because the secret
should not be exposed to the client browser, the library requires a server that:

* Accepts an unsigned request.
* Signs it.
* Forwards the request to Ooyala's API service.

No signing server is needed for the actual uploading  of files or chunks. For a video, the client receives the
URLs for uploading from the Ooyala API and directly posts to those URLs.

## Initialization

The Ooyala uploader is initialized with a configuration hash. The possible configuration hashes are as
follows:

* **event: callback**:  Callback functions for each of the supported events described in the next section.
* **uploaderType**: Type of uploader. Valid Values: `"HTML5"` | `"Flash"`. Default: `"HTML5"`.
* **swfUploader**: Reference to the swfUploader object. Only required if uploaderType is "Flash"

## Events

The following events are recognized by the Backlot Uploader JavaScript Library:

* **embedCodeReady**: Asset was created and an embed code is available. Callback parameter: `assetID`.
* **uploadProgress**: File upload in progress. Callback parameters: `assetID`, `progressPercent`.
* **uploadComplete**: Upload has completed. Callback parameter: `assetID`.
* **uploadError**: An error occurred during the upload process. Callback parameters: `assetID`, `type`,
  `fileName`, `statusCode`, `message`. The error parameter is a hash containing error messages.

## Methods

The Backlot Uploader JavaScript Library includes the following methods.

* **.on(event, callback)**: Add a callback function for any of the uploader events.
* **.uploadFile(file, options)**: The `uploadFile` method using the HTML5 File APIs to upload the asset in
  chunks. It requires a reference to a file and can include the `options` hash, described below.
* **.uploadFileUsingFlash(options)**: The `uploadFileUsingFlash` method uses the swfUpload library to upload
 the asset in a single chunk. To use this method, the page must contain an initialized swfUpload swf.
 The `options` hash is described below


## Options hash for uploadFile and uploadFileUsingFlash

The `uploadFile` method takes in a file reference and an options hash. The possible options are:

* **assetType**: Type of asset. Valid Values: `"video"` | `"ad"`. Default: `"video"`.
* **name**: Asset name. Default: the specified filename.
* **description**: Asset description. Default: none.
* **postProcessingStatus**: Status after processing. Valid values: `"live"` | `"paused"`. Default: `"live"`.
* **labels**: An array of labels to be assigned to the asset. If a label does not exist, it is created.
  Format: Labels must be specified by their full paths.
* **assetCreationUrl**: URL on your signing server for creating assets. The corresponding Backlot API URI is
  `[POST] /v2/assets`. Note: This is a URI on your own server that signs requests before sending them to
  Ooyala. The name of your URI should be specified in this variable. Ooyala recommends using the default here
  so you can pass a parameterized URL that includes the asset ID. Default: `"/v2/assets"`.
* **assetStatusUpdateUrl**: URL on your signing server to update asset’s upload status. Corresponding Backlot
  API is `[PUT] /v2/assets/assetID/upload_status`.  Default: `"/v2/assets/assetID/upload_status"`. The
  string assetID will be replaced for the actual id of the asset.
* **assetUploadingUrl**: URL on your signing server to GET the asset's uploading URLs. Corresponding Backlot
  API is `[GET] /v2/assets/assetID/uploading_urls`. Default: `"/v2/assets/assetID/uploading_urls"`. The
  string assetID will be replaced for the actual ID of the asset.
* **labelCreationUrl**: URL on your signing server for creating labels. Corresponding Backlot API is `[POST]
  /v2/labels/by_full_path/paths`. Default: `"/v2/labels/by_full_path/paths"`. The paths variable is a
  comma-delimited list of full path names for labels, including the leading slash, such as
  `/sports/baseball/giants` or `/sports/baseball/49er`
* **labelAssignmentUrl**: URL on your signing server to assign labels to assets. Corresponding Backlot API is
  `[POST] /v2/assets/assetID/labels`. Default: `"/v2/assets/assetID/labels"`.


## Using the HTML5 Uploader

On page load, create a new instance of the OoyalaUploader. When a file input change event is called, invoke
the uploadFile method with the desired options hash. The following is a stripped-down version of the
SampleDriver class in sample_driver.coffee

    window.SampleDriver = (function() {
      function SampleDriver() {}

      SampleDriver.init = function() {
        $("#html5InputFile").change(SampleDriver.handleFileSelect);
        return SampleDriver.ooyalaUploader = new OoyalaUploader({
          uploadComplete: SampleDriver.uploadComplete,
          uploaderType: "HTML5"
        });
      };

      SampleDriver.handleFileSelect = function(event) {
        var file, options;
        file = event.target.files[0];
        options = {
          name: "Sample Name",
          labels: ["/label1"]
        };
        return SampleDriver.ooyalaUploader.uploadFile(file, options);
      };

      SampleDriver.uploadComplete = function(assetID) {
        return console.log("" + assetID + " Upload Completed");
      };

      return SampleDriver;

    }).call(this);


## Using the Flash Uploader

For browsers without the File API, the swfUpload flash file should be embedded on the page. The swfUpload
[documentation](http://demo.swfupload.org/Documentation/#settingsobject) shows the different ways the flash
button can be styled.

OoyalaUploader must only be initialized after the swfUpload file has been loaded. The following is a stripped-down version of the SampleDriver class in sample_driver.coffee


    window.SampleDriver = (function() {
      function SampleDriver() {}

      SampleDriver.init = function() {
        SampleDriver.initSWFUploader();
        return SampleDriver.ooyalaUploader = new OoyalaUploader({
          uploadComplete: SampleDriver.uploadComplete,
          uploaderType: "Flash",
          swfUploader: SampleDriver.swfUploader
        });
      };

      SampleDriver.initSWFUploader = function() {
        var settingsObject;
        settingsObject = {
          file_queue_limit: 1,
          file_upload_limit: 1,
          file_dialog_complete_handler: SampleDriver.handleFlashFileSelect,
          flash_url: "http://localhost:7081/swfupload.swf",
          button_placeholder_id: "flashInputButton",
          button_image_url: "BrowseButton.png",
          button_height: 22,
          button_width: 61
        };
        return SampleDriver.swfUploader = new SWFUpload(settingsObject);
      };

      SampleDriver.handleFlashFileSelect = function(numFilesSelected, numFilesQueued, numFilesInQueue) {
        var options;
        options = {
          name: "Sample Name",
          labels: ["/label1"]
        };
        return SampleDriver.ooyalaUploader.uploadFileUsingFlash(options);
      };

      SampleDriver.uploadComplete = function(assetID) {
        return console.log("" + assetID + ": Upload Completed");
      };

      return SampleDriver;

    }).call(this);


## Getting Started

### Sample Implementation
The ruby_backend_server in the examples directory has a sample implementation of the library in Ruby. To run the server,

    $ bundle install
    $ API_KEY="YourAPIKey" SECRET="YourSecret" V2_API_URL="http://api.ooyala.com" bin/rerun_uploader_server.sh
    $ Point your browser to http://localhost:7081/

### API Dummy Server
The examples directory contains a dummy server that simulates a basic version of the Ooyala V2 APIs for
testing.
To run the server,

    $ bundle install
    $ bin/rerun_dummy_server.sh

