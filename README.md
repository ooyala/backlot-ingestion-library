# Ooyala Backlot Uploader JavaScript Library v2

## Overview

The Ooyala Backlot Uploader JavaScript library is an easy way to integrate with Ooyala's ingestion application
programming interface (API). It uses the HTML5 File API to chunk a file in the client and upload the chunks
to Ooyala's servers.

Because the library uses the HTML5 File APIs to chunk files, it requires a browser that supports the File
APIs. Supported browsers are Firefox 15+, Chrome 22+, Safari 6+, and IE with the ChromeFrame plugin.

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
URLs for uploading directly from the Ooyala API and directly posts to to those URLs on the Ooyala service.

## Initialization

The Ooyala uploader is initialized with a configuration hash. The possible configuration hashes are as
follows:

* **event: callback**:  Callback functions for each of the supported events described in the next section.

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
* **.uploadFile(file, options)**: The `uploadFile` method requires a reference to a file and can include the
  `options` hash, described below.

## uploadFile Options

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
* **labelCreationUrl**: URL on your signing server for creating labels. Corresponding Backlot API is `[POST]
  /v2/labels/by_full_path/paths`. Default: `"/v2/labels/by_full_path/paths"`. The paths variable is a
  comma-delimited list of full path names for labels, including the leading slash, such as
  `/sports/baseball/giants` or `/sports/baseball/49er`
* **labelAssignmentUrl**: URL on your signing server to assign labels to assets. Corresponding Backlot API is
  `[POST] /v2/assets/assetID/labels`. Default: `"/v2/assets/assetID/labels"`.

## Getting Started

### API Dummy Server
The examples directory contains a dummy server that simulates a basic version of the Ooyala V2 APIs that
can be used for testing.
To run the server,

    $ bundle install
    $ bin/rerun_dummy_server.sh

### Ruby Backend Server
The ruby_backend_server in the examples directory has a reference server implementation. To run the server,

    $ bundle install
    $ bin/rerun_uploader_server.sh
    $ Point your browser to http://localhost:7081/

