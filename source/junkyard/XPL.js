if (!this.Meeko) this.Meeko = {}

Meeko.XPL = (function() {

var Binding = function(classSpec) { // 
	var constructor = function() {
		if (!(this instanceof arguments.callee)) return null;
		if (classSpec.constructor) classSpec.constructor.apply(this, arguments);
		return this;
	}
	
	constructor.prototype.__attach = function(external) {
		for (var propertyName in classSpec.prototype) {
			if (/^_/.test(propertyName)) continue;
			if (!external[propertyName]) external[propertyName] = function() { internal[propertyName].apply(this, arguments); }
		}
	}		
	
	for (var propertyName in classSpec) {
		if (!this[propertyName]) this[propertyName] = classSpec[propertyName];
	}
	
	return constructor;	
}

var Mixin = function(classSpec) {
	var constructor = function() {
		if (this instanceof arguments.callee) return;
		// else mixin
		for (var propertyName in classSpec.prototype) {
			if (!this[propertyName]) this[propertyName] = classSpec[propertyName];
		}	
	}
	
	for (var propertyName in classSpec) {
		if (!this[propertyName]) this[propertyName] = classSpec[propertyName];
	}
	
	return constructor;
},

var Class = function(classSpec) {
	var constructor = function() {
		if (classSpec.__constructor) classSpec.__constructor.apply(this, arguments);
	}

	if (classSpec.__extends) constructor.prototype = new classSpec.__extends;
	for (var propertyName in classSpec) {
		if ("prototype" == propertyName) for (var methodName in classSpec.prototype) {
			constructor.prototype[methodName] = classSpec.prototype[methodName];
		}
		if (!this[propertyName]) this[propertyName] = classSpec[propertyName];
	}
	
	constructor.__extend = function(target) {
		for (var propertyName in this.prototype) {
			target[propertyName] = this.prototype[propertyName];
		}
	}

	constructor.prototype.__bind = function(external) {
		var internal = this;
		for (var propertyName in this.prototype) {
			if (!external[propertyName]) external[propertyName] = function() { internal[propertyName].apply(this, arguments); }
		}
	}
	
	return constructor;
},

var Package = function(pkgSpec) {
	var pkg = function() {
		for (var className in pkgSpec) {
			if (/^_/.test(propertyName)) continue;
			var constructor = pkgSpec[className];
			if (!this[className]) this[className] = new constructor();
			else constructor.apply(this[className]);
		}
	}
	
	pkg.__extend = function(target, priority) {
		for (var className in this.__PUBLIC__) {
			if (target[className]) this[className].__extend(target[className], priority);
			else target[className] = this[className];
		}
	}
	
	return pkg;
}



return {
	Package: Package,
	Class: Class
}

})();

