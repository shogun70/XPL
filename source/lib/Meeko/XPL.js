
if (!window.Meeko) window.Meeko = {};
if (!Meeko.XPL) Meeko.XPL = (function() {

var Namespace = function() {};
Namespace.enhance = function(dest, src) {
	for (var className in src) {
		var srcClass = src[className];
		var destClass = dest[className];
		if (destClass) {
			for (var propName in srcClass) {
				if ("prototype" == propName) continue;
				if (destClass[propName]) continue;
				else destClass[propName] = srcClass[propName];
			}
			if (srcClass.prototype && null == destClass.prototype) destClass.prototype = {}; // NOTE fixes DOMException on Opera and Safari2
			for (var propName in srcClass.prototype) {
				if (destClass.prototype[propName]) continue;
				else destClass.prototype[propName] = srcClass.prototype[propName];
			}
		}
		else dest[className] = srcClass;
	}
}

var Logger = function(ref) {
	this.ref = ref;
}

Logger.DEBUG = 0;
Logger.INFO = 1;
Logger.WARN = 2;
Logger.ERROR = 3;

Logger.prototype.log = function() { this._log({ message: arguments }); }
Logger.prototype.debug = function() { this._log({ level: Logger.DEBUG, message: arguments }); }
Logger.prototype.info = function() { this._log({ level: Logger.INFO, message: arguments }); }
Logger.prototype.warn = function() { this._log({ level: Logger.WARN, message: arguments }); }
Logger.prototype.error = function() { this._log({ level: Logger.ERROR, message: arguments }); }

Logger.prototype._log = function(data) {
	data.date = new Date;
	data.ref = this.ref;
	data.message = Array.prototype.join.call(data.message, " ");
	if (this._trace) this._trace.log(data);
}

var XPLContext = function(ref) {
	this.params = {};
	this.requiredContexts = [];
	this.installed = false;
	this.logger = new Logger(ref);
}

var XPLSystem = function() {
	this.prefetch = {};
	this.contexts = {};
	this.documentURI = document.documentURI || document.baseURI || document.URL;
	this.boundDocumentURI = this.documentURI; // FIXME orthogonality
}

XPLSystem.prototype.createContext = function(ref) {
	if (null == ref) { ref = 0; for (var text in this.contexts) ref++; } // NOTE default value for ref is the current number of contexts;
	var xplContext = new XPLContext(ref);
	this.contexts[ref] = xplContext;
	xplContext.logger._trace = this.trace;
	return xplContext;
}

XPLSystem.prototype.createNamespace = function(name) { // TODO error checking
	var a = name.split(".");
	var ns = window;
	for (var n=a.length, i=0; i<n; i++) {
		var step = a[i];
		if (!ns[step]) ns[step] = {};
		ns = ns[step];
	}
	return ns;
}

XPLSystem.prototype.init = function() {
	var xplSystem = this;
	function require(href) {
		var xplContext = xplSystem.contexts[href];
		if (xplContext.installed) return true;
		for (var n=xplContext.requiredContexts.length, i=0; i<n; i++) {
			require(xplContext.requiredContexts[i]);
		}
		var rc = xplContext.wrappedScript.call(window);
		xplContext.installed = true; // FIXME
		return rc;
	}
	for (var href in xplSystem.contexts) require(href);
}

var Script = function() {
	this.readyState = "initialized";
}

Script.runList = [];

Script.prototype.run = function(text) {
	function setText(_elt, _text) {
		_elt.text = _text;
		if (!_elt.innerHTML) _elt.appendChild(document.createTextNode(_text));
	}
	var scriptElt = document.createElement("script");
	scriptElt.type = "text/javascript";

	this.scriptElement = scriptElt;
	this.scriptIndex = Script.runList.length;
	Script.runList.push(this);

	this.readyState = "loaded";
	setText(scriptElt, 
		'try {\n' +
		text + '\n' +
		' Meeko.XPL.Script.runList[' + this.scriptIndex + '].readyState = "complete";\n' +
		'}\n' +
		'catch (__xplError__) {\n' +
		' Meeko.XPL.Script.runList[' + this.scriptIndex + '].readyState = "error";\n' +
		'}\n'
	);
	
	var callbackElt = document.createElement("script");
	callbackElt.type = "text/javascript";
	
	this.callbackElement = callbackElt;
	setText(callbackElt, 'window.setTimeout(function() { Meeko.XPL.Script.runList[' + this.scriptIndex + '].callback(); }, 10);');

	var head = document.getElementsByTagName("head")[0];
	head.appendChild(scriptElt);
	head.appendChild(callbackElt);
}

Script.prototype.callback = function() {
	var head = this.scriptElement.parentNode;
	head.removeChild(this.scriptElement);
	head.removeChild(this.callbackElement);
	if (this.readyState == "error") {
	}
	else if (this.readyState == "loaded") {
		this.readyState = "syntax-error";
	}
	if (this.onreadystatechange) this.onreadystatechange();
}


return {
	Namespace: Namespace,
	XPLContext: XPLContext,
	XPLSystem: XPLSystem,
	Script: Script
}

})();

if (!Meeko.stuff) Meeko.stuff = {};
if (!Meeko.stuff.xplSystem) Meeko.stuff.xplSystem = (function() {

var xplSystem = new Meeko.XPL.XPLSystem();
var traceWindow = window;
do {
	if (traceWindow && traceWindow.Meeko && traceWindow.Meeko.stuff && traceWindow.Meeko.stuff.trace) {
		xplSystem.trace = {
			_log: traceWindow.Meeko.stuff.trace.log,
			log: function(data) {
				data.url = xplSystem.documentURI; 
				data.boundDocumentURI = xplSystem.boundDocumentURI; // FIXME orthogonality
				this._log(data);
			}
		}
		break;
	}
	if (traceWindow == top) break; // need to break at top because top.parent == top
} while (traceWindow = traceWindow.parent);

if (!xplSystem.trace) {
	xplSystem.trace = {
		log: function(data) {}
	}
}

return xplSystem;
})();

if (!Meeko.stuff.execScript) Meeko.stuff.execScript = function(text, callback) {
	var script = new Meeko.XPL.Script;
	if (callback) script.onreadystatechange = function() { callback(script.readyState); };
	script.run(text);
}

if (!Meeko.stuff.evalScript) Meeko.stuff.evalScript = function() {
	return eval(arguments[0]);
}

// NOTE emulate firebug behavior which complements the XMLHttpRequest wrapper in Meeko.xml
if (XMLHttpRequest && !XMLHttpRequest.wrapped) var XMLHttpRequest = (function() {
	var _xhr = window.XMLHttpRequest;
	var xhr = function() { return new _xhr; };
	xhr.wrapped = _xhr;
	return xhr;
})();

// NOTE cross-browser error catch-all
//if (window.addEventListener) window.addEventListener("error", function(event) { event.preventDefault(); }, false);
//else window.onerror = function(event) { return true; }; // FIXME

