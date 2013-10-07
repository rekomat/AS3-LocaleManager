# AS3-LocaleManager 

The AS3-LocaleManager provides basic localization support for ActionScript apps. It takes care of loading/parsing resource bundle files (*.txt) and returns localized resources based on the precedence of the locales set in localeChain.

For some reason, mx.flex.ResourceManager does not always work as expected [1]. I ran into this issue while working on a AS3 project for AIR 3.6 (using Flash Builder 4.7). This class is a quick workaround for the problem. 

[1] http://forums.adobe.com/message/5182578

__Note: This code has not been tested in a production environment yet. Improvements welcome!__

## Resource files

The bundle files are stored in `app://locale/[locale]/[bundleName].txt`  (ie.: `app://locale/en_US/localizedStrings.txt`). Make sure the directory "locale" is copied to your build package:

* Put the directory locale in your src directory.
* Or add the directory containing 'locale' to your Source Path (Flash Builder: Project > Properties > ActionScript Build Path > Source Path).

The content format for bundle files is `KEY = Value` followed by a line break. __You can use the "=" character within the value, but not for keys or comments.__

    # Any line without the "equals" character is a comment. 
    A leading # does not harm.
    LABEL_FIRSTNAME = Firstname
    LABEL_LASTNAME  = Lastname

The locales are returned by precedence given in localeChain. Mix-ins are supported. This allows to work with incomplete bundles (ie. separate bundles for different regions of the same language). 

## Usage Sample

### Resource files

    // File: de_DE/bundleName.txt
    // Complete resource file
    CURRENCY_SHORT = EUR
    PRICE          = Preis
    USRMSG_UNLOCK  = Gratulation {0}, du hast jetzt {1}!

    // File: de_CH/bundleName.txt
    // Incomplete resource file (used as mix-in)
    CURRENCY_SHORT = CHF
    
The sample uses mix-ins and placeholders.

### Initialize LocaleManager and set localeChain 
I recommend to use the handy [LocaleUtil](https://code.google.com/p/as3localelib/) to sort supported locales based on system preferences. 

```as3
var locales:LocaleManager = new LocaleManager();
locales.localeChain = LocaleUtil.sortLanguagesByPreference(
    ["de_CH", "de_DE", en_US], Capabilities.languages, "en_US");
```

### Adding required bundles

Use `addRequiredBundles` to add all required bundles. This is typically used on startup. The bundle files are loaded/parsed at runtime. Adding only the required bundles saves time.

```as3
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
```

If you work with a single resource bundle per locale and you do not need mix-ins, this will do the job: 
```as3
locales.addRequiredBundles([
    {locale:locales.localeChain[0], bundleName:"bundleName"}
], onComplete);

// complete responder (s. above)
```

### Adding additional bundles

With `addBundle` you can add bundles later. If you have an app with many scenes/levels and many resources in your bundles it might be better to split the resources into several bundles and just load the ones really needed (ie. when switching levels). 

```as3
locales.addBundle("en_US", "bundleName", onComplete);

// optional complete responder
function onComplete(locale:String, bundleName:String, success:Boolean):void
{
    if ( success ) trace("Bundle " + locale + "/" + bundleName + " added.");
    else trace("Adding bundle " + locale + "/" + bundleName + " failed.");
}
```
Use `locales.localeChain[0]` as parameter if you just need to add a single bundle for the primary locale.
```as3
locales.addBundle(locales.localeChain[0], "anotherBundleName", onComplete);

// complete responder (s. above)
```

### Retrieving resources 

`getString` returns a given resource of a given bundle. Localized of course. The third sample shows how to use placeholders and parameters. 

```as3
// given localeChain ["de_CH","de_DE"]
locales.getString("bundleName", "PRICE"); // Preis
locales.getString("bundleName", "CURRENCY_SHORT"); // CHF
locales.getString("bundleName", "USRMSG_UNLOCK", ["Superman", "Superkraft"]); // Gratulation Superman, du hast jetzt Superkraft!
```

## Make it better
Suggestions, improvements, feedback and whatever is welcome! 
[@rekomat](https://twitter.com/rekomat)
