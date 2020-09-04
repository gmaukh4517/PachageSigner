
var reg_url = /^[^\?]+\?([\w\W]+)$/,
reg_para = /([^&=]+)=([\w\W]*?)(&|$|#)/g,
arr_url = reg_url.exec(window.location.href),
query = {};
if (arr_url && arr_url[1]) {
	var str_para = arr_url[1], result;
	while ((result = reg_para.exec(str_para)) != null) {
		query[result[1]] = result[2];
	}
}

var main = new Vue({
	el: '.platform_wrapper',
	data: {
		selected_paltform: query.platform,
		bundle_id: query.bundleID,
		page: 1,
		pageCount: 10,
		apps: [],
		show_load_more_apps_button: true,
		changelog_box_show_index:-1,
	},
	methods: {
		loadApps: function () {
			var that = this;
			axios.get("/apps/"+this.selected_paltform+"/"+this.bundle_id+"/"+this.page+"/"+this.pageCount).then(function(response) {
	            that.apps = that.apps.concat(response.data)
	            that.page++
	            that.show_load_more_apps_button = response.data.length == that.pageCount
	        });
		},
		installation:function(url,event){
				if(event) {
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
  			}
			window.location.href = url;
		},
		downloadFile:function(guid,event){
			if(event) {
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
  			}
  			if (this.isPC()) {
  				window.location.href = window.location.origin + "/ipa/" + guid + ".ipa";	
  			}
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
		toggleChangelog:function(index,event){
			if(event)
   				event.stopPropagation ? event.stopPropagation(): event.cancelBubble = true;
  			
  			if (index != this.changelog_box_show_index) {
  				this.changelog_box_show_index = index;	
  			}else{
  				this.changelog_box_show_index = -1;
  			}
		},
	},
	computed: {
		has_data: function () {
			return this.apps.length > 0
		}
	}
});
main.loadApps()
