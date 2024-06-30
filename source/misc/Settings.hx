package misc;

import haxe.Json;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import misc.Highscore;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.util.FlxSave;

using StringTools;

/*
    Settings handling experimental change. Here the settings work a little differently.
    Normally in base Assorion they are a struct where the defaults are loaded from a JSON file.

    The settings use reflection to check to make sure the settings struct contains the correct values
    to the ones stored in the save data. However this system has a few benefits:
    - No default settings JSON needed
    - No need to reference Settings.pr when looking for an option
    - Defaults are stored right here.

    The settings now work not by using a struct, but instead by storing a class with a ton of static variables
    which contain the default settings. This is similar to Psych Engine's ClientPrefs but there's a bit of a difference.

    There is a Settings class which ONLY contains the settings as static variables. Then there is the SettingsManager (formerly settings)
    which handles loading, applying, and saving all of the settings stored in the class.

    The save data is also handled a little differently as well believe it or not. Before the settings were a structure,
    and you can simply just save the structure directly in the 'gSave' variable. Here it's a little different. Instead
    the settings are saving in a map but through the use of reflection, the map is translated in to the variables for the
    Settings class. 

    The flush function also has to do some extra logic to read all of the variables from the Settings class and translate
    them back into the map to be saved. One of the main downsides is that unless the map is set to null, then the
    map still exists which is not very efficient. Perhaps this may change in an update.

*/
class Settings {
    public static var start_fullscreen:Bool = false;
    public static var start_volume:Int      = 100;
    public static var skip_splash:Bool      = false;
    public static var default_persist:Bool  = false;
    public static var pre_caching:Bool      = false;

    public static var downscroll:Bool    = true;
    public static var audio_offset:Int   = 75;
    public static var input_offset:Int   = 0;
    public static var botplay:Bool       = false;
    public static var ghost_tapping:Bool = true;

    public static var useful_info:Bool   = true;
    public static var antialiasing:Bool  = true;
    public static var show_hud:Bool      = true;
    public static var framerate:Int      = 120;

    // controls :(
    public static var note_left :Array<Int> = [KeyCode.A, KeyCode.LEFT];
    public static var note_right:Array<Int> = [KeyCode.D, KeyCode.RIGHT];
    public static var note_up   :Array<Int> = [KeyCode.W, KeyCode.UP];
    public static var note_down :Array<Int> = [KeyCode.S, KeyCode.DOWN];
    
    public static var ui_left :Array<Int>  = [KeyCode.A, KeyCode.LEFT];
    public static var ui_right:Array<Int>  = [KeyCode.D, KeyCode.RIGHT];
    public static var ui_up   :Array<Int>  = [KeyCode.W, KeyCode.UP];
    public static var ui_down :Array<Int>  = [KeyCode.S, KeyCode.DOWN];
    public static var ui_accept:Array<Int> = [KeyCode.RETURN, KeyCode.SPACE];
    public static var ui_back  :Array<Int> = [KeyCode.ESCAPE, KeyCode.BACKSPACE];
}

#if !debug @:noDebug #end
class SettingsManager {
    // We have to store all variables in a map, since otherwise there's no way to flush the values.
    public static var gsTranslator:Map<String, Dynamic>;
    public static var gSave:FlxSave;

    public static function openSettings(){
        gSave = new FlxSave();
        gSave.bind('assorion', 'candicejoe');

        gsTranslator = gSave.data.settings == null ? new Map<String, Dynamic>() : gSave.data.settings;

        var settItems:Array<String> = Type.getClassFields(Settings);
        for(k in gsTranslator.keys()){
            if(settItems.contains(k)){
                Reflect.setField(Settings, k, gsTranslator.get(k));
                trace('Set $k to ${Reflect.field(Settings, k)}');
            } else
                trace('settItems did not contain: ${k}');
        }

        trace('$gsTranslator');

        Settings.framerate = framerateClamp(Settings.framerate);
        Binds.updateControls();
        Highscore.loadScores();
    }
    
    public static function apply(){
        FlxGraphic.defaultPersist = Settings.default_persist;
        FlxG.updateFramerate = FlxG.drawFramerate = framerateClamp(Settings.framerate);

        Main.changeUsefulInfo(Settings.useful_info);
        Paths.switchCacheOptions(Settings.default_persist);

        Main.framerateDivision = 60 / FlxG.updateFramerate;
    }

    public inline static function flush(){
        var settItems:Array<String> = Type.getClassFields(Settings);
        for(i in 0...settItems.length)
            gsTranslator.set(settItems[i], Reflect.field(Settings, settItems[i]));
            //Reflect.setField(gSave.data, settItems[i], Reflect.field(Settings, settItems[i]));

        gSave.data.settings = gsTranslator;
        gSave.flush();
    }

    // Though we clamp it as 340, the game will still update up to 500 FPS anyway.
    public static inline function framerateClamp(ch:Int):Int
        return CoolUtil.intBoundTo(ch, 10, 340);
}

// Maps a key code to a string. Includes shifting.
// TODO: Add more characters.
class InputString {
    public static function getKeyNameFromString(code:Int, literal:Bool = false, shiftable:Bool = true):String{
        var shifted:Bool = false;
        if(shiftable)
            shifted = FlxG.keys.pressed.SHIFT;

        switch(code){
            case -2:
                return 'ALL';
            case -1:
                return 'NONE';
            case 65:
                return 'A';
            case 66:
                return 'B';
            case 67:
                return 'C';
            case 68:
                return 'D';
            case 69:
                return 'E';
            case 70:
                return 'F';
            case 71:
                return 'G';
            case 72:
                return 'H';
            case 73:
                return 'I';
            case 74:
                return 'J';
            case 75:
                return 'K';
            case 76:
                return 'L';
            case 77:
                return 'M';
            case 78:
                return 'N';
            case 79:
                return 'O';
            case 80:
                return 'P';
            case 81:
                return 'Q';
            case 82:
                return 'R';
            case 83:
                return 'S';
            case 84:
                return 'T';
            case 85:
                return 'U';
            case 86:
                return 'V';
            case 87:
                return 'W';
            case 88:
                return 'X';
            case 89:
                return 'Y';
            case 90:
                return 'Z';

            case 48:
                if(shifted){
                    if(literal) return ')';
                    return 'CLOSED BRACKET';
                }
                    
                return '0';
            case 49:
                if(shifted){
                    if(literal) return '!';
                    return 'EXCLAIMATION';
                }

                return '1';
            case 50:
                if(shifted){
                    if(literal) return '@';
                    return 'AT SIGN';
                }
                return '2';
            case 51:
                if(shifted){
                    if(literal) return '#';
                    return 'HASHTAG';
                }
                return '3';
            case 52:
                if(shifted){
                    if(literal) return '$';
                    return 'DOLLAR SIGN';
                }
                return '4';
            case 53:
                if(shifted){
                    if(literal) return '%';
                    return 'PERCENT';
                }
                return '5';
            case 54:
                if(shifted){
                    if(literal) return '^';
                    return 'CARET';
                }
                return '6';
            case 55:
                if(shifted){
                    if(literal) return '&';
                    return 'AMPERSAND';
                }
                return '7';
            case 56:
                if(shifted){
                    if(literal) return '*';
                    return 'ASTERISK';
                }
                return '8';
            case 57:
                if(shifted){
                    if(literal) return '(';
                    return 'OPEN BRACKET';
                }
                return '9';   
                
            case 13:
                return 'ENTER';
            case 33:
                return 'PAGE UP';
            case 34:
                return 'PAGE DOWN';
            case 35:
                return 'END';
            case 36:
                return 'HOME';
            case 45:
                return 'INSERT';
            case 46:
                return 'DELETE';
            case 27:
                return 'ESCAPE';
            case 189:
                if(shifted){
                    if(literal) return '_';
                    return 'UNDERSCORE';
                }
                if(literal)
                    return '-';
                return 'MINUS';
            case 187:
                if(shifted){
                    if(literal) return '+';
                    return 'PLUS';
                }
                if(literal)
                    return '=';
                return 'EQUALS'; 
            case 8:
                return 'BACK';
            case 219:
                if(shifted){
                    if(literal) return '{';
                    return 'OPEN BRACE';
                }
                if(literal)
                    return '[';
                return 'OPEN BRACE';
            case 221:
                if(shifted){
                    if(literal) return '}';
                    return 'CLOSED BRACE';
                }
                if(literal)
                    return ']';
                return 'CLOSED BRACE';
            case 220:
                return '\\';
            case 222:
                if(shifted){
                    if(literal) return '"';
                    return "QUOTE";
                }
                if(literal)
                    return "'";
                return "APOSTROPHE";
            case 188:
                if(shifted)
                    return '<';
                return ',';
            case 191:
                if(shifted)
                    return '?';
                return '/';
            case 18:
                return 'ALT';
            case 17:
                return 'CONTROL';
            case 190:
                if(shifted)
                    return '>';
                return '.';
            case 16:
                return 'SHIFT';
            case 32:
                if(literal)
                    return ' ';
                return 'SPACE';
            case 37:
                return 'LEFT';
            case 40:
                return 'DOWN';
            case 38:
                return 'UP';
            case 39:
                return 'RIGHT';
            case 186:
                if(shifted){
                    if(literal) return ':';
                    return 'COLON';
                }
                if(literal)
                    return ';';
                return 'SEMICOLON';
        }

        trace('Couldn\'t find the character');
        return 'UNKNOWN';
    }
}