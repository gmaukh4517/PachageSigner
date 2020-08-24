#!/usr/bin/env node

var fs = require('fs-extra');
var https = require('https');
var path = require('path');
var exit = process.exit;
var pkg = require('./package.json');
var version = pkg.version;
var AdmZip = require("adm-zip");
var program = require('commander');
var express = require('express');
var mustache = require('mustache');
var strftime = require('strftime');
var underscore = require('underscore');
var os = require('os');
var multiparty = require('multiparty');
var sqlite3 = require('sqlite3');  
var uuidV4 = require('uuid/v4');
var extract = require('ipa-extract-info');
var apkParser3 = require("apk-parser3");
require('shelljs/global');

/** 格式化输入字符串**/

//用法: "hello{0}".format('world')；返回'hello world'

String.prototype.format= function(){
  var args = arguments;
  return this.replace(/\{(\d+)\}/g,function(s,i){
    return args[i];
  });
}

before(program, 'outputHelp', function() {
  this.allowUnknownOption();
});

program
    .version(version)
    .usage('[option] [dir]')
    .option('-p, --port <port-number>', 'set port for server (defaults is 1234)')
    .option('-h, --host <host>', 'set host for server (defaults is your LAN ip)')
    .parse(process.argv);

var port = program.port || 1234;

// var ipAddress = 'localios.tianyuyou.cn';
// var certificateName = 'tianyuyou.cn';
// var certificateType = '.pem';

var certificateName = 'mycert1';
var certificateType = '.cer';
var ipAddress = program.host || underscore
  .chain(require('os').networkInterfaces())
  .values()
  .flatten()
  .find(function(iface) {
    return iface.family === 'IPv4' && iface.internal === false;
  })
  .value()
  .address;

var serverDir = os.homedir() + "/.ipapk-server/"
var globalCerFolder = serverDir + ipAddress;
var ipasDir = serverDir + "ipa";
var apksDir = serverDir + "apk";
var iconsDir = serverDir + "icon";
var sqlite3Dir = serverDir + "database"
createFolderIfNeeded(serverDir)
createFolderIfNeeded(ipasDir)
createFolderIfNeeded(apksDir)
createFolderIfNeeded(iconsDir)
createFolderIfNeeded(sqlite3Dir)
function createFolderIfNeeded (path) {
  if (!fs.existsSync(path)) {  
    fs.mkdirSync(path, function (err) {
        if (err) {
            console.log(err);
            return;
        }
    });
  }
}

function excuteDB(cmd, params, callback) {
  var db = new sqlite3.Database(sqlite3Dir +'/'+ 'database.sqlite3');
  db.run(cmd, params, callback);
  db.close();
}

function queryDB(cmd, params, callback) {
  var db = new sqlite3.Database(sqlite3Dir +'/'+ 'database.sqlite3');
  db.all(cmd, params, callback);
  db.close();
}

excuteDB("CREATE TABLE IF NOT EXISTS info (\
  id integer PRIMARY KEY autoincrement,\
  guid TEXT,\
  platform TEXT,\
  milieu TEXT,\
  name TEXT,\
  displayName TEXT,\
  bundleID TEXT,\
  version TEXT,\
  build TEXT,\
  size TEXT,\
  uploadTime datetime default (datetime('now', 'localtime')),\
  changelog TEXT\
  )");
/**
 * Main program.
 */
process.exit = exit

// CLI
var basePath = "https://{0}:{1}".format(ipAddress, port);
if (!exit.exited) {
  main();
}

/**
 * Install a before function; AOP.
 */

function before(obj, method, fn) {
  var old = obj[method];

  obj[method] = function() {
    fn.call(this);
    old.apply(this, arguments);
  };
}

function main() {

  console.log(basePath);

  var key;
  var cert;

  try {
    key = fs.readFileSync(globalCerFolder + '/' + certificateName + '.key', 'utf8');
    cert = fs.readFileSync(globalCerFolder + '/' + certificateName + certificateType, 'utf8');
  } catch (e) {
    var result = exec('sh  ' + path.join(__dirname, 'bin', 'generate-certificate.sh') + ' ' + ipAddress).output;
    key = fs.readFileSync(globalCerFolder + '/' + certificateName + '.key', 'utf8');
    cert = fs.readFileSync(globalCerFolder + '/' + certificateName + certificateType, 'utf8');
  }

  var options = {
    key: key,
    cert: cert
  };

  var app = express();
  app.use('/cer', express.static(globalCerFolder));
  app.use('/', express.static(path.join(__dirname,'web')));
  app.use('/ipa', express.static(ipasDir));
  app.use('/apk', express.static(apksDir));
  app.use('/icon', express.static(iconsDir));
  app.get(['/apps/:platform','/apps/:platform/:page','/apps/:platform/:page/:pageCount'], function(req, res, next) {
  	  res.set('Access-Control-Allow-Origin','*');
      res.set('Content-Type', 'application/json');
      var page = parseInt(req.params.page ? req.params.page : 1);
      var pageCount = parseInt(req.params.pageCount ? req.params.pageCount : 10);
      if (req.params.platform === 'android' || req.params.platform === 'ios') {
        queryDB("select * from (select * from info where platform=?  order by uploadTime desc ) as temp_table group by bundleID limit ?,?", [req.params.platform, (page - 1) * pageCount, page * pageCount], function(error, result) {
          if (result) {
          	var results = result.sort((c,b)=>{
              return (c.uploadTime<b.uploadTime)?1:-1
            })
            res.send(mapIconAndUrl(results))
          } else {
            errorHandler(error, res)
          }
        })
      }
  });

  app.get(['/apps/:platform/:bundleID','/apps/:platform/:bundleID/:page' , '/apps/:platform/:bundleID/:page/:pageCount'], function(req, res, next) {
  	  res.set('Access-Control-Allow-Origin','*');
      res.set('Content-Type', 'application/json');
      var page = parseInt(req.params.page ? req.params.page : 1);
      var pageCount = parseInt(req.params.pageCount ? req.params.pageCount : 10);
      if (req.params.platform === 'android' || req.params.platform === 'ios') {
        queryDB("select * from info where platform=? and bundleID=? order by uploadTime desc limit ?,? ", [req.params.platform, req.params.bundleID, (page - 1) * pageCount, page * pageCount], function(error, result) {
          if (result) {
            res.send(mapIconAndUrl(result))
          } else {
            errorHandler(error, res)
          }
        })
      }
  });

  app.get('/plist/:guid', function(req, res) {
    queryDB("select displayName,name,bundleID,version from info where guid=?", [req.params.guid], function(error, result) {
      if (result) {
        fs.readFile(path.join(__dirname, 'templates') + '/template.plist', function(err, data) {
            if (err) throw err;
            var template = data.toString();
            var rendered = mustache.render(template, {
              guid: req.params.guid,
              name: result[0].displayName || result[0].name,
              bundleID: result[0].bundleID,
              version: result[0].version,
              basePath: basePath,
            });
            res.set('Content-Type', 'text/plain; charset=utf-8');
            res.set('Access-Control-Allow-Origin','*');
            res.send(rendered);
        })
      } else {
        errorHandler(error, res)
      }
    })
  });

  app.post('/upload', function(req, res) {
    var form = new multiparty.Form();
    form.parse(req, function(err, fields, files) {
      if (err) {
        errorHandler(err, res);
        return;
      }
      var changelog;
      if (fields.changelog) {
        changelog = fields.changelog[0];
      }

      var milieu;
      if (fields.milieu) {
        switch(fields.milieu[0]){
          case "1":
            milieu = "正式";
            break;
          case "2":
            milieu = "灰度"
            break;
          case "3":
            milieu = "测试"
            break;
          case "4":
            milieu = "开发"
            break;
        }
      }

      if (!files.package) {
        errorHandler("params error",res)
        return
      }

      var obj = files.package[0];
      var tmp_path = obj.path;
      parseAppAndInsertToDb(tmp_path, changelog,milieu, info => {
        storeApp(tmp_path, info["guid"], error => {
          if (error) {
            errorHandler(error,res)
          }
          console.log(info)
          res.send(info)
        })

      }, error => {
        errorHandler(error,res)
      });
    });
  });

  https.createServer(options, app).listen(port);
}

function errorHandler(error, res) {
  console.log(error)
  res.send({"error":error})
}

function mapIconAndUrl(result) {
  var items = result.map(function(item) {
    item.icon = "{0}/icon/{1}.png".format(basePath, item.guid);
    if (item.platform === 'ios') {
      item.url = "itms-services://?action=download-manifest&url={0}/plist/{1}".format(basePath, item.guid);
    } else if (item.platform === 'android') {
      item.url = "{0}/apk/{1}.apk".format(basePath, item.guid);
    }
    return item;
  })
  return items;
}

function parseAppAndInsertToDb(filePath, changelog, milieu, callback, errorCallback) {
  var guid = uuidV4();
  var parse, extract
  if (path.extname(filePath) === ".ipa") {
    parse = parseIpa
    extract = extractIpaIcon
  } else if (path.extname(filePath) === ".apk") {
    parse = parseApk
    extract = extractApkIcon
  } else {
    errorCallback("params error")
    return;
  }
  Promise.all([parse(filePath),extract(filePath,guid)]).then(values => {
    var info = values[0];
    info["guid"] = guid;
    info["changelog"] = changelog;
    info["milieu"] = milieu;
    excuteDB("INSERT INTO info (guid, platform, milieu, name, displayName, build, bundleID, version, size, changelog) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
    [info["guid"], info["platform"],info["milieu"],info["name"],info["displayName"], info["build"], info["bundleID"], info["version"], info["size"], changelog],function(error){
        if (!error){
          callback(info)
        } else {
          errorCallback(error)
        }
    });
  }, reason => {
    errorCallback(reason)
  })
}

function storeApp(fileName, guid, callback) {
  var new_path;
  if (path.extname(fileName) === ".ipa") {
    new_path = path.join(ipasDir, guid + ".ipa");
  } else if (path.extname(fileName) === ".apk") {
    new_path = path.join(apksDir, guid + ".apk");
  }
  fs.rename(fileName,new_path,callback)
}

function parseIpa(filename) {
  return new Promise(function(resolve,reject){
    var fd = fs.openSync(filename, 'r');
    extract(fd, function(err, info, raw){
    if (err) reject(err);
      var data = info[0];
      var info = {}
      info["platform"] = "ios"
      info["name"] = data.CFBundleName,
      info["displayName"] = data.CFBundleDisplayName,
      info["build"] = data.CFBundleVersion,
      info["bundleID"] = data.CFBundleIdentifier,
      info["version"] = data.CFBundleShortVersionString,
      info["size"] = parseBytes(fs.statSync(filename).size)
      resolve(info)
    });
  });
}

function parseApk(filename) {
  return new Promise(function(resolve,reject){
    apkParser3(filename, function (err, data) {
        var package = parseText(data.package);
        var info = {
          "name":data["application-label"].replace(/'/g,""),
          // "displayName": application.label,
          "build":package.versionCode,
          "bundleID":package.name,
          "version":package.versionName,
          "platform":"android",
          "size": parseBytes(fs.statSync(filename).size)
        }
        resolve(info)
    });
  });
}

function parseBytes(bytes) {
  if(bytes < 1024) return bytes + "B";
  else if(bytes < 1048576) return(bytes / 1024).toFixed(2) + "KB";
  else if(bytes < 1073741824) return(bytes / 1048576).toFixed(2) + "MB";
  else return(bytes / 1073741824).toFixed(2) + "GB";
};

function parseText(text) {
  var regx = /(\w+)='([\w\.\d]+)'/g
  var match = null, result = {}
  while(match = regx.exec(text)) {
    result[match[1]] = match[2]
  }
  return result
}

function extractApkIcon(filename,guid) {
  return new Promise(function(resolve,reject){
    apkParser3(filename, function (err, data) {
      var iconPath = false;
      [640,320,240,160].every(i=>{
        if(typeof data["application-icon-"+i] !== 'undefined'){
          iconPath=data["application-icon-"+i];
          return false;
        }
        return true;
      });
      if(!iconPath){
        reject("can not find icon ");
      }

      iconPath = iconPath.replace(/'/g,"")
      var tmpOut = iconsDir + "/{0}.png".format(guid)
      var zip = new AdmZip(filename); 
      var ipaEntries = zip.getEntries();
      var found = false
      ipaEntries.forEach(function(ipaEntry) {
        if (ipaEntry.entryName.indexOf(iconPath) != -1) {
          var buffer = new Buffer(ipaEntry.getData());
          if (buffer.length) {
            found = true
            fs.writeFile(tmpOut, buffer,function(err){  
              if(err){  
                  reject(err)
              }
              resolve({"success":true})
            })
          }
        }
      })
      if (!found) {
        reject("can not find icon ")
      }
    });
  })
}

function extractIpaIcon(filename,guid) {
  return new Promise(function(resolve,reject){
    debugger;
    var tmpOut = iconsDir + "/{0}.png".format(guid)
    var zip = new AdmZip(filename);
    var ipaEntries = zip.getEntries();
    var found = false;
    ipaEntries.forEach(function(ipaEntry) {
      if (ipaEntry.entryName.indexOf('AppIcon60x60@2x.png') != -1) {
        found = true;
        var buffer = new Buffer(ipaEntry.getData());
        if (buffer.length) {
          fs.writeFile(tmpOut, buffer,function(err){  
            if(err){  
              reject(err)
            } else {
              var execResult = exec(path.join(__dirname, 'bin','pngdefry -s _tmp ') + ' ' + tmpOut)
              if (true) { //  pngdefry 判定图片不是PNG 
                resolve({"success":true})
              } else {
                fs.remove(tmpOut,function(err){  
                  if(err){
                    reject(err)
                  } else {
                    var tmp_path = iconsDir + "/{0}_tmp.png".format(guid)
                    fs.rename(tmp_path,tmpOut,function(err){
                      if(err){
                        reject(err)
                      } else {
                        resolve({"success":true})
                      }
                    })
                  }
                })
              }
            }
          })
        }
      }
    })
    if (!found) {
      reject("can not find icon ")
    }
  })
}
