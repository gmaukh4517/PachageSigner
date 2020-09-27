new Vue({
    el: '.app_wrapper',
    data: {
        uploadFiles: [],
        milieus: [{
                milieuName: '正式',
                milieu: 1,
                selected: false,
            },
            {
                milieuName: '灰度',
                milieu: 2,
                selected: false,
            },
            {
                milieuName: '测试',
                milieu: 3,
                selected: false,
            },
            {
                milieuName: '开发',
                milieu: 4,
                selected: true,
            },
        ],
    },
    mounted: function() {
        let _this = this;
        var dropbox = document.getElementById('drop_area');

        dropbox.addEventListener("drop", this.enentDrop, false)
        dropbox.addEventListener("dragleave", function(e) {
            e.stopPropagation();
            e.preventDefault();
            _this.borderhover = false;
        })
        dropbox.addEventListener("dragenter", function(e) {
            e.stopPropagation();
            e.preventDefault();
            _this.borderhover = true;
        })
        dropbox.addEventListener("dragover", function(e) {
            e.stopPropagation();
            e.preventDefault();
            _this.borderhover = true
        })
        var drop_area_file = document.getElementById('drop_area_file');
        drop_area_file.addEventListener("change", this.getUploadFile, false)
        dropbox.onclick = function(event) {
            drop_area_file.dispatchEvent(new MouseEvent('click'))
        }
    },
    methods: {
        enentDrop: function(e) {
            this.borderhover = false;
            e.stopPropagation();
            e.preventDefault(); //必填字段
            this.handlerUploadFile(e.dataTransfer.files);
        },
        getUploadFile(event) {
            this.handlerUploadFile(event.target.files);
        },
        handlerUploadFile(files) {
            for (let i = 0; i < files.length; i++) {
                let file = files[i];
                let fileType = files[i].type;
                let idx = file.name.lastIndexOf(".");
                if (idx != -1) {
                    fileType = file.name.substr(idx + 1).toLowerCase();
                }

                if (fileType == 'ipa' || fileType == 'apk') {
                    let uploadFileJson = {
                        file: file,
                        fileName: file.name,
                        fileSize: this.getFileSize(file.size),
                        fileType: fileType,
                        fileUploadRate: 0,
                        fileUploadStyle: {
                            width: '0%'
                        }
                    };
                    this.uploadFiles.push(uploadFileJson);
                } else {
                    console.log(file.name + " " + "不支持此类型文件");
                }
            }
        },
        getFileSize: function(fileByte) {
            var fileSizeByte = fileByte;
            var fileSizeMsg = "";
            if (fileSizeByte < 1048576) fileSizeMsg = (fileSizeByte / 1024).toFixed(2) + "KB";
            else if (fileSizeByte == 1048576) fileSizeMsg = "1MB";
            else if (fileSizeByte > 1048576 && fileSizeByte < 1073741824) fileSizeMsg = (fileSizeByte / (1024 * 1024)).toFixed(2) + "MB";
            else if (fileSizeByte > 1048576 && fileSizeByte == 1073741824) fileSizeMsg = "1GB";
            else if (fileSizeByte > 1073741824 && fileSizeByte < 1099511627776) fileSizeMsg = (fileSizeByte / (1024 * 1024 * 1024)).toFixed(2) + "GB";
            else fileSizeMsg = "文件超过1TB";
            return fileSizeMsg;
        },
        deleteUploadFile: function(file, index) {
            this.uploadFiles.splice(index, 1);
        },
        submitUploadFiles: function() {
            if (this.uploadFiles.length == 0) {
                alert('请选择要上传的文件');
                return;
            }
            var that = this;
            var successCount = 0,
                failureCount = 0;
            for (var i = 0; i < this.uploadFiles.length; i++) {
                var uploadFile = this.uploadFiles[i];
                if (uploadFile.fileUploadRate == 0) {
                    this.submitUploadRequest(uploadFile, i, function(data, error) {
                        if (error == null) {
                            console.log(data);
                            successCount++;
                        } else {
                            failureCount++;
                        }

                        if (successCount + failureCount == that.uploadFiles.length) {
                            that.uploadFiles.splice(0, that.uploadFiles.length);
                        }
                    });
                }
            }
        },
        submitUploadRequest: function(uploadFile, index, responseCallback) {
            var uploadFileInfo = document.getElementById(index);
            var select = uploadFileInfo.getElementsByTagName('select')[0];
            select.disabled = true;
            var textarea = uploadFileInfo.getElementsByTagName('textarea')[0];
            textarea.disabled = true;

            let formData = new FormData();
            formData.append('package', uploadFile.file);
            formData.append('changelog', textarea.value);
            formData.append('milieu', this.milieus[select.selectedIndex].milieu);
            let config = {
                headers: {
                    'Content-Type': 'multipart/form-data',
                },
                onUploadProgress: function(progressEvent) { //监听用于上传显示进度
                    if (progressEvent.lengthComputable) {
                        var rate = progressEvent.loaded / progressEvent.total;
                        if (rate <= 1) {
                            uploadFile.fileUploadRate = rate;
                            uploadFile.fileUploadStyle.width = (rate * 100).toFixed(2) + '%';
                        }
                    }
                }
            };

            axios.post("/upload", formData, config).then((response) => {
                if (response.data) {
                    responseCallback(response.data, null);
                }
            }).catch(function(req) {
                console.log(req, "请求失败的回调，自己看看为啥失败");
                responseCallback(null, req);
            });
        },
    },
    computed: {

    }
});