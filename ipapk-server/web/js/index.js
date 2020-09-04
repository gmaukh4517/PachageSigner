
var main = new Vue({
	el: '.platform_wrapper',
	data: {
		selected_paltform:'',
		ios_page: 1,
		andorid_page:1,
		pageCount: 10,
		apps: [],
		show_load_more_apps_button: false,
		iosApps:[],
		androidApps:[],
		changelog_box_show_index:-1,
	},
	methods: {
		switchPlatform: function (event) {
			var platform = event.target.innerText.toLowerCase()
			if (this.selected_paltform !== platform) {
				this.selected_paltform = platform
				if (platform == 'ios') {
					if ( this.iosApps.length<=0) {
						this.loadApps()		
					}else{
						this.apps = this.iosApps
					}
				}else if (platform == 'android') {
					if ( this.androidApps.length<=0) {
						this.loadApps()		
					}else{
						this.apps = this.androidApps
					}
				}
			}
		},
		loadApps: function () {
			var apps_page = this.ios_page
			if (this.selected_paltform == 'android') {
				apps_page = this.andorid_page
			}

			var that = this;
			axios.get("/apps/"+this.selected_paltform+"/"+apps_page+"/"+this.pageCount).then(function(response){
	            if (that.selected_paltform == 'ios') {
	            	that.ios_page++
	            	that.apps = that.iosApps = that.iosApps.concat(response.data)
				}else if (that.selected_paltform == 'android') {
					that.andorid_page++
					that.apps = that.androidApps = that.androidApps.concat(response.data)
				}
	            that.show_load_more_apps_button = response.data.length > 9
	        });
		},
		viewAllVersion: function (e) {
			if (event) {
				 event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
			}
			window.location.href += "versionlist.html?platform=" + this.selected_paltform + "&bundleID=" + event.currentTarget.getAttribute('bundle-id')
		},
		installation:function(url,event){
				if(event) {
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
  			}
			window.location.href = url;
		},
		isPC:function(){
			var sUserAgent= navigator.userAgent.toLowerCase();
			var bIsIpad= sUserAgent.match(/ipad/i) == "ipad";
			var bIsIphoneOs= sUserAgent.match(/iphone os/i) == "iphone os";
			var bIsMidp= sUserAgent.match(/midp/i) == "midp";
			var bIsUc7= sUserAgent.match(/rv:1.2.3.4/i) == "rv:1.2.3.4";
			var bIsUc= sUserAgent.match(/ucweb/i) == "ucweb";
			var bIsAndroid= sUserAgent.match(/android/i) == "android";
			var bIsCE= sUserAgent.match(/windows ce/i) == "windows ce";
			var bIsWM= sUserAgent.match(/windows mobile/i) == "windows mobile";
			return !(bIsIpad || bIsIphoneOs || bIsMidp || bIsUc7 || bIsUc || bIsAndroid || bIsCE || bIsWM);
		},
		downloadFile:function(guid,event){
			if(event) {
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
  			}
  			if (this.isPC()) {
  				window.location.href += "ipa/" + guid + ".ipa";	
  			}
		},
		toggleChangelog:function(index,event){
			if(event)
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
  			
  			if (index != this.changelog_box_show_index) {
  				this.changelog_box_show_index = index;	
  			}else{
  				this.changelog_box_show_index = -1;
  			}
		},
		uploadFiles:function(event){
			if(event)
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
   			if (this.isPC()) {
  				window.location.href += "/uploadFiles.html";	
  			}
		}
	}
});
new Vue({
	el: '.qrcode_wrapper',
	data: {
		qrcode_box_show: true,
		
	},
	methods: {
		toggleQrcode: function () {
			this.qrcode_box_show = !this.qrcode_box_show
		},
	}
});

main.selected_paltform = 'ios';
main.loadApps()
new QRCode(document.getElementsByClassName('qrcode_pic')[0], {
	text: location.href,
	width: 160,
	height: 160,
	colorDark : "#000000",
	colorLight : "#ffffff",
	correctLevel : QRCode.CorrectLevel.H
});