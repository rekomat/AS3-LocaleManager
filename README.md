# AS3-LocaleManager 

The AS3-LocaleManager provides basic localization support for ActionScript apps. It takes care of loading/parsing resource bundle files (*.txt) and returns localized resources based on the precedence of the locales set in localeChain.

For some reason, mx.flex.ResourceManager does not always work as expected [1]. I ran into this issue while working on a AS3 project for AIR 3.6 (using Flash Builder 4.7). This class is a quick workaround for the problem. 

[1] http://forums.adobe.com/message/5182578

__Note: This code has not been tested in a production environment yet. Improvements welcome!__

## Resource files

The bundle files are stored in `app://locale/[locale]/[bundleName].txt`  (ie.: `app://locale/en_US/localizedStrings.txt`). Make sure the directory "locale" is copied to your build package:

* Put the directory locale in your src directory.
* Add the directory containing 'locale' to your Source Path (Flash Builder: Project > Properties > ActionScript Build Path > Source Path).

The content format for bundle files is `KEY = Value` followed by a line break. __You can use the "=" character within the value, but not for keys or comments.__

    # Any line without the "equals" character is a comment. 
    A leading # does not harm.
    LABEL_FIRSTNAME = Firstname
    LABEL_LASTNAME  = Lastname

The locales are returned by precedence given in localeChain. Mix-ins are supported. This allows to work with incomplete bundles (ie. separate bundles for different regions of the same language). 

## Usage Sample

Resource files (mix-in sample)

    // de_DE/bundleName.txt
    CURRENCY_SHORT = EUR
    PRICE          = Preis

    // de_CH/bundleName.txt
    CURRENCY_SHORT = CHF

Initialize LocaleManager and set localeChain (ie. using the handy [LocaleUtil](https://code.google.com/p/as3localelib/) to sort supported locales based on system preferences). 

    var locales:LocaleManager = new LocaleManager();
    locales.localeChain = LocaleUtil.sortLanguagesByPreference(
        ["de_CH", "de_DE", en_US], Capabilities.languages, "en_US");

Adding _required bundles_

The bundle files are loaded/parsed during runtime. Adding only the required bundles saves time.

    locales.addRequiredBundles([
        {locale:"de_DE", bundleName:"bundleName"},
        {locale:"de_CH", bundleName:"bundleName"}
    ], onComplete);
    
    // optional complete responder
    function onComplete(success:Boolean):void
    {
        if ( success ) trace("Required bundles successfully added.");
	    else trace("Adding required bundles failed.");
    }


Adding additional bundles

    locales.addBundle("en_US", "bundleName", onComplete);
    
    // optional complete responder
    function onComplete(locale:String, bundleName:String, success:Boolean):void
    {
        if ( success ) trace("Bundle " + locale + "/" + bundleName + " added.");
        else trace("Adding bundle " + locale + "/" + bundleName + " failed.");
    }

Retrieving resources 

    // given localeChain ["de_CH","de_DE"]
    trace(locales.getString("bundleName", "PRICE")); // Preis
    trace(locales.getString("bundleName", "CURRENCY_SHORT")); // CHF

