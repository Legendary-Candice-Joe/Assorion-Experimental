package ui;

import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import misc.MenuTemplate;

/*
    Just a modified -
    Optionstate for controls
*/

#if !debug @:noDebug #end
class ControlsState extends MenuTemplate {
	var controlList:Array<String> = [
        'ui_down',
        'ui_up',
        'ui_left',
        'ui_right',
        '',
        'note_left',
        'note_down',
        'note_up',
        'note_right',
        '',
        'ui_accept',
        'ui_back'
    ];
    var rebinding:Bool = false;
    var dontCancel:Bool = false;

	override function create()
	{
        addBG(FlxColor.fromRGB(0,255,110));
        columns = 3;
		super.create();

		createNewList();
	}

	public function createNewList(){
		clearEverything();

		for(i in 0...controlList.length){
			pushObject(new Alphabet(0, MenuTemplate.yOffset+20, controlList[i], true));

            var str:String = '';
            var s2r:String = '';

            if(controlList[i] != ''){
                var val:Dynamic = Reflect.field(Settings, controlList[i]);
                str = misc.InputString.getKeyNameFromString(val[0], false, false);
                s2r = misc.InputString.getKeyNameFromString(val[1], false, false);
            }

			pushObject(new Alphabet(0, MenuTemplate.yOffset+20, str, true));
			pushObject(new Alphabet(0, MenuTemplate.yOffset+20, s2r, true));
		}

		changeSelection();
	}

    override function update(elasped:Float){
        super.update(elasped);

        if(!rebinding || !FlxG.keys.justPressed.ANY) 
            return;

        if(dontCancel){
            dontCancel = false;
            return;
        }
    }

	override public function exitFunc(){
		if(NewTransition.skip())
            return;

        MusicBeatState.changeState(new OptionsState());
	}

    // Skip blank space
	override public function changeSelection(to:Int = 0){
		if(curSel + to >= 0 && controlList[curSel + to] == '')
			to *= 2;

		super.changeSelection(to);
	}

	override public function keyHit(KC:KeyCode, mod:KeyModifier){
		if(rebinding){
            var k:Int = KC;
            var original:Dynamic = Reflect.field(Settings, controlList[curSel]);
                original[curAlt] = k;

            Reflect.setField(Settings, '${controlList[curSel]}', original);
    
            rebinding = false;
            createNewList();

            trace(k);

            return;
        }

        super.keyHit(KC, mod);

		if(!KC.hardCheck(Binds.UI_ACCEPT) || controlList[curSel] == '') 
            return;

		for(i in 0...arrGroup.length)
			if(Math.floor(i / columns) != curSel)
				arrGroup[i].targetA = 0;

		dontCancel = true;
		rebinding = true;
		return;
	}
}
