require "./uploader_server"

map(UploaderServer.pinion.mount_point) { run UploaderServer.pinion }
map("/") { run UploaderServer }
