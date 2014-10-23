#!/usr/bin/nodejs

// transcode.js
//
// Transcodes music in a FLAC library to a given format
//
// Available transcode targets:
// - Opus (opusenc)
//
// Planned future transcode targets:
// - AAC  (neroAacEnc)
// - MP3  (lame)
//

var path = require('path'),
    fs = require('fs')
    os = require('os');

var ExitCode = {
  BadArgs: 63,
  MissingProgram: 64
};

function printUsage() {
  console.log("$(basename $0) recursively transcodes music in a FLAC library to a given format.\n");
  
  console.log("Usage: $(basename $0) <options> <source> <destination>\n");
  
  console.log("Source      : Directory to recurse through and transcode FLAC files from");
  console.log("Destination : Directory to place transcoded files (structure will match source)\n");
  
  console.log("  -o, --opus=n     Encode in Opus with loose VBR bitrate of n kbps");

  console.log("eg: $(basename $0) -o 140 . ~/transcode")
}

function getOpusTranscoder(bitrate) {
  return function opusTranscode(encode) {
    console.log("Transcoding " + encode.source);
    console.log(" to         " + encode.destination + ".opus ");
    console.log(" at " + bitrate + "kbps.\n");
  }
}

var maxThreads = os.cpus().length;

// Get subdirectory names inside `dir`
function getDirs(dir) {
  return fs.readdirSync(dir).filter(function (file) {
    return fs.statSync(path.join(dir,file)).isDirectory();
  });
}

var flacfileRegex = /.+\.flac$/i; // Must have a name and end with ".flac" (case-insensitive)
function getFlacFiles(dir) {
  return fs.readdirSync(dir).filter(function (file) {
    return flacfileRegex.test(file) && fs.statSync(path.join(dir,file)).isFile();
  });
}

function transcodeDirectory(sourceRoot, targetRoot, transcode) {
  var pathStack = [];
  var dirs = [];
  var encodes = [];
  
  function recurseInto(dir) {
    pathStack.push(dir);
    
    dirs.push(path.join(targetRoot, path.join.apply(path, pathStack.slice(1))));
    
    var subdirs = getDirs(path.join.apply(path, pathStack));
    subdirs.forEach(recurseInto);
    
    var flacFiles = getFlacFiles(path.join.apply(path, pathStack));
    flacFiles.forEach(function (flacFile) {
      var fileTrunc = flacFile.substring(0, flacFile.length - 5); // 5 is the length of ".flac"
      encodes.push({
        source: path.join(path.join.apply(path, pathStack), flacFile), 
        destination: path.join(targetRoot, path.join.apply(path, pathStack.slice(1)), fileTrunc)
      });
    });
    
    pathStack.pop();
  }
  
  recurseInto(sourceRoot);
  
  dirs.forEach(function(dir) {
    if (!fs.existsSync(dir)) {
      console.log("Creating directory at " + dir + " ...");
      fs.mkdirSync(dir, "0755");
    }
    else if (!fs.statSync(dir).isDirectory()) {
      throw dir + " exists, but isn't a directory! Aborting.";
    }
  });
  
  encodes.forEach(transcode);
}

var argv = require('minimist')(process.argv.slice(2));
console.log("Arguments as parsed: ");
console.dir(argv);
console.log();

var sourceDir = path.resolve(argv._[0]);
if (!fs.statSync(sourceDir).isDirectory()) process.exit(ExitCode.BadArgs);
	      
var targetDir = path.resolve(argv._[1]);
if (!fs.statSync(path.join(targetDir, '..')).isDirectory()) process.exit(ExitCode.BadArgs);
    
var opusBitrate = (+argv.opus >= 6 && +argv.opus) || (+argv.o >= 6 && +argv.o);
if (opusBitrate)
{
  transcodeDirectory(path.resolve(argv._[0]), path.resolve(argv._[1]), getOpusTranscoder(opusBitrate));
}

