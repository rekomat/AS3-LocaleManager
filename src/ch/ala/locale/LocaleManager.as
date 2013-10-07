// =================================================================================================
//
//	LocaleManager
//	Copyright 2013 ala pixel LLC, <http://ala.ch>. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package ch.ala.locale
{
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.utils.Dictionary;
	import flash.utils.clearTimeout;
	import flash.utils.setTimeout;
	
	import mx.utils.StringUtil;

	/** LocaleManager provides basic localization support. It takes care of loading/parsing
	 *  resource bundle files (*.txt) and returns localized resources based on the precedence 
	 *  of the locales set in localeChain.
	 * 
	 *  <p>The bundle files are stored in app://locale/[locale]/[bundleName].txt 
	 *  (ie.: app://locale/en_US/localizedStrings.txt).
	 * 
	 *  <p>The content format for bundle files is <code>KEY = Value[Linebreak]</code>. 
	 *  <strong>You can use the = sign within the value, but not for keys or comments.</strong> 
	 *  
	 *  <p>Sample:<br/>
	 *  <code>
	 *  # Any line without "equals" char is a comment.<br/>
	 *  LABEL_FIRSTNAME = Firstname<br/>
	 *  LABEL_LASTNAME  = Lastname<br/>
	 *  </code>
	 * 
	 *  <p>The locales are returned by precedence given in localeChain. Mix-ins are supported. 
	 *  This allows to work with incomplete bundles (ie. separate bundles for different regions 
	 *  of the same language). 
	 * 
	 *  <p>Sample: <br/>
	 *  de_DE: CURRENCY_SHORT = EUR, PRICE = Preis<br/>
	 *  de_CH: CURRENCY_SHORT = CHF
	 * 
	 *  <p>If localeChain is ["de_CH", "de_DE"] PRICE would return "Preis" while CURRENCY_SHORT
	 *  would return "CHF" */
	public class LocaleManager
	{
		/*  === Static Constants ===  */
		
		/*  === Properties ===  */
		
		private var _localeChain:Array;
		
		private var _requiredBundlesReady:Boolean;
		
		/** The list of loaded and parsed bundles. */
		private var bundles:Dictionary;
		
		/** Bundle files are loaded in queue. When adding bundles, they're pushed into this 
		 *  queue and removed from queue when loading and parsing is completed or if an 
		 *  error occurs. */
		private var loadingQueue:Array;
		
		/** When a bundle has been loaded an parsed, the next bundle in queue is loaded
		 *  with a delay of 1ms using setTimeout. This way the frame rate has a chance to breathe, 
		 *  specially if parsing larger files. */
		private var timeoutID:uint;
		
		private var _verbose:Boolean = false;
		
		
		/*  === Setup ===  */
		
		/** Creates a new LocaleManager. */
		public function LocaleManager()
		{
			_localeChain          = new Array();
			_requiredBundlesReady = true;
			bundles               = new Dictionary();
			loadingQueue          = new Array();
		}
		
		
		/*  === Load and parse resource bundle files ===  */
		
		/** Adds a set of required resource bundles and an optional responder function.
		 *  The responder is invoked when all required bundles are ready. The parameter indicates
		 *  whether adding the bundles was successful. 
		 * 
		 *  <p>Bundles added this way take precedence over the ones added with addBundle. 
		 * 
		 *  <p>Parameter bundles contains Objects with properties locale and bundleName
		 *  <code>
		 *  [{locale:"fr_CA", bundleName:"LocalizedStrings"}, <br/>
		 *  {locale:"fr_FR", bundleName:"LocalizedStrings"}] 
		 *  </code> */
		public function addRequiredBundles(bundles:Array, onRequiredComplete:Function = null):void
		{
			_requiredBundlesReady = false;
			
			// required bundles take precedence in queue (duplicate check done before loading)
			for ( var i:int = bundles.length - 1; i >= 0; i-- ) 
			{
				loadingQueue.unshift({
					"locale":     bundles[i].locale,
					"bundleName": bundles[i].bundleName,
					"onComplete": onComplete
				});
			}
			
			// set to false if any of the required bundles fails
			var successForAll:Boolean = true;
			
			// start loading if not already in progress
			if ( loadingQueue.length == bundles.length )
				loadBundle();
			
			function onComplete(locale:String, bundleName:String, success:Boolean):void
			{
				if ( onRequiredComplete is Function )
				{
					// if loading/parsing failed
					if ( !success ) successForAll = false;
					
					// abort if other required bundles are still in queue 
					var length:uint = loadingQueue.length;
					for ( var i:uint = 0; i < length; i++ ) 
						if ( loadingQueue[i].onComplete === onComplete ) return;
					
					// invoke responder if all required bundles ready
					if ( successForAll ) _requiredBundlesReady = true;
					onRequiredComplete(successForAll);
				}
			}
		}
		
		
		/** Adds a resource bundle of a given name and locale to the loading queue. */
		public function addBundle(locale:String, bundleName:String, onComplete:Function = null):void
		{
			// adding bundle to the queue (duplicate check done before loading)
			loadingQueue.push({
				"locale":     locale,
				"bundleName": bundleName,
				"onComplete": onComplete
			});
			
			// start loading if not already in progress
			if ( loadingQueue.length == 1 )
				loadBundle();
		}
		
		
		/** Unqueues the first bundle in queue and invokes loading of the next resource bundle. */
		private function unqueueFirst(success:Boolean):void
		{
			var identifier:Object = loadingQueue.shift();

			// invoke responder if set
			if ( identifier.onComplete is Function ) 
				identifier.onComplete(identifier.locale, identifier.bundleName, success);

			timeoutID = setTimeout(loadBundle, 1);
		}
		
		
		/** Loads an queued resource bundle. */
		private function loadBundle():void
		{
			if ( timeoutID ) clearTimeout(timeoutID);
			
			// abort if loading queue empty
			if ( loadingQueue.length < 1 ) return;
			
			// get the first object from queue
			var identifier:Object = loadingQueue[0];

			// abort if bundle already available
			if ( identifier.locale in bundles 
				&& identifier.bundle in bundles[identifier.locale] ) 
			{
				log("loadBundle: Bundle " + identifier.locale + "/" + identifier.bundle + " is already available.");
				unqueueFirst(true);
				return;
			}
			
			// File reference pointing to app://locale/[locale]/[bundleName].txt 
			// (ie.: app://locale/en_US/localizedStrings.txt)
			var file:File = File.applicationDirectory.resolvePath(
				"locale/" + identifier.locale + "/" + identifier.bundleName + ".txt");

			// if file not found
			if ( !file.exists ) 
			{
				log("File locale/" + identifier.locale + "/" + identifier.bundleName + ".txt does not exist.");
				unqueueFirst(false);
				return;
			}

			// try to open file stream (async)
			var fileStream:FileStream = new FileStream();
			fileStream.addEventListener(Event.COMPLETE, onComplete);
			try 
			{
				log("Loading resource bundle " + identifier.locale + "/" + identifier.bundleName + ".");
				fileStream.openAsync(file, FileMode.READ);
			}
			catch(e:Error) 
			{
				log("Could not open FileStream. Error: " + e.toString());
				unqueueFirst(false);
			}
			
			// file content read completely: try to parse content
			function onComplete(event:Event):void
			{
				var success:Boolean = false;
				try 
				{
					parseBundle(identifier.locale, identifier.bundleName, 
						fileStream.readUTFBytes(fileStream.bytesAvailable));
					success = true;
				}
				catch(e:Error)
				{
					log("Could not read/parse FileStream. Error: " + e.toString());
				}
				finally
				{
					fileStream.close();
					unqueueFirst(success);
				}
			}
		}
		
		
		/** Parses the contents of a resource file (*.txt) and adds it to the list of loaded bundles. */
		private function parseBundle(locale:String, bundleName:String, content:String):void
		{
			// create the new bundle
			if ( !(locale in bundles) ) bundles[locale] = new Dictionary();
			bundles[locale][bundleName] = new Dictionary();
			
			// parsing the input line by line
			var lines:Array = content.split("\n");
			var length:uint = lines.length;
			var pair:Array;
			for ( var i:int = 0; i < length; i++ ) 
			{
				pair = lines[i].split("=", 2);
				// ignore blank lines and comments (all lines without "=")
				if ( pair.length < 2 ) continue; 
				// assign the key/value pair
				bundles[locale][bundleName][StringUtil.trim(pair[0])] = StringUtil.trim(pair[1]);
			}
		}
		
		
		/*  === Retrieving resources ===  */
		
		/** Returns the localized resource from a given bundle of a given resource name based on 
		 *  the precedence in localeChain if available or an empty String if not. */ 
		public function getString(bundleName:String, resourceName:String, parameters:Array = null):String
		{
			var length:uint = _localeChain.length;
			for ( var i:uint = 0; i < length; i++ ) 
			{
				if ( _localeChain[i] in bundles 
					&& bundleName in bundles[_localeChain[i]] 
					&& resourceName in bundles[_localeChain[i]][bundleName] )
				{
					var value:String = bundles[_localeChain[i]][bundleName][resourceName];
					if (parameters)
						value = StringUtil.substitute(value, parameters);
					return value;
				}
			}
			log("getString(" + bundleName + ", " + resourceName +"): No matching resource found.");
			return "";
		}

		
		/*  === Getter/Setter ===  */
		
		/** Locales ordered by precedence (ie. ["en_US", "en_CA", "fr_CA", "fr_FR"]). */
		public function get localeChain():Array { return _localeChain; }
		public function set localeChain(value:Array):void
		{
			_localeChain = value;
		}
		
		/** Indicates whether all required bundles are ready. 
		 *  <p>NOTE: Will return true if no required bundles have been added. */
		public function get requiredBundlesReady():Boolean { return _requiredBundlesReady; }

		/** If verbose is set true, output is logged to the console. */
		public function get verbose():Boolean { return _verbose; }
		public function set verbose(value:Boolean):void
		{
			_verbose = value;
		}
		
		
		/*  === Helpers ===  */
		
		/** Logs output to the console if verbose is true. */
		private function log(msg:String):void
		{
			if ( verbose )
				trace("[LocaleManager] " + msg);
		}


	}
}
