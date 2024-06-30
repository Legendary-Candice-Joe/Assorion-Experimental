package misc;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.group.FlxGroup.FlxTypedGroup;
import ui.NewTransition;
import ui.MainMenuState;
import gameplay.HealthIcon;

/*
    A helper class that others can inherit from.
    Like freeplay or optionsstate.
*/

typedef MenuObject = {
	var obj:FlxSprite;
	var targetX:Int;
	var targetY:Int;
	var targetA:Float;
}

class MenuTemplate extends MusicBeatState {
    /* Configure menu spacings, applies to Pause substate as well.
       If you want the menus to have the base game positioning, replace the values with the comment values. */
    public static inline var xOffset:Int = 60;  // 90
    public static inline var xDiffer:Int = 20;
    public static inline var yOffset:Int = 110; // 345
    public static inline var yDiffer:Int = 110; // 156

    public var curSel:Int  = 0;
    public var curAlt:Int  = 0;
    public var columns:Int = 1;

    private var arrGroup:Array<MenuObject> = [];
    private var arrIcons:FlxTypedGroup<HealthIcon>;

    var camFollow:FlxObject;

    private inline function addBG(bgColour:Int, ?sprite:String = "ui/menuDesat"){
        var background = new StaticSprite(0,0).loadGraphic(Paths.lImage('ui/menuDesat'));
        background.scale.set(1.1, 1.1);
        background.screenCenter();
        background.scrollFactor.set(0, 0.5);
        background.color = bgColour;
        add(background);
    }

    override function create(){
        arrIcons = new FlxTypedGroup<HealthIcon>();
        camFollow = new FlxObject(0,0,1,1);
        FlxG.camera.follow(camFollow, null, 0.023);

        add(arrIcons);

        super.create();

        postEvent(0, function(){
            changeSelection(0);
        });
    }

    public inline function pushObject(spr:FlxBasic){
        var cr:MenuObject = {
            obj: cast spr,
            targetX: xOffset + ((arrGroup.length + 1) * xDiffer),
            targetY: yOffset + Math.round((arrGroup.length + 1) * yDiffer / columns),
            targetA: 0.4
        };

        cr.obj.alpha = 0.4;
        cr.obj.scrollFactor.set();

        arrGroup.push(cr);
        add(cr.obj);
    }

    public inline function pushIcon(icn:HealthIcon){
        arrIcons.add(icn);
        icn.scale.set(0.85, 0.85);
    }

    // Camera fix

    #if (flixel < "5.4.0")
    public override function stepHit(){
        super.stepHit();
        FlxG.camera.followLerp = (1 - Math.pow(0.5, FlxG.elapsed * 2)) * Main.framerateDivision;
    }
    #end

    // Modified add function

    public inline function sAdd(crap:FlxBasic){
        add(crap);

        var scrap:FlxObject = cast crap;
        if (scrap != null)
            scrap.scrollFactor.set();
    }

    public function changeSelection(to:Int = 0){
        FlxG.sound.play(Paths.lSound('ui/scrollMenu'));

        var loopNum = Math.floor(arrGroup.length / columns);
        curSel += to + loopNum;
		curSel %= loopNum;

        for(i in 0...loopNum){
            var item = arrGroup[i * columns];

            item.targetX = (i - curSel) * xDiffer;
            item.targetX += xOffset;
            item.targetY = (i - curSel) * yDiffer;
            item.targetY += yOffset;
            item.targetA = i == curSel ? 1 : 0.4;

            if(columns <= 1) 
                continue;

            for(x in 1...columns){
                var sn = columns - 1;
                var offItem = arrGroup[(i * columns) + x];

                offItem.obj.screenCenter(X);
                offItem.obj.x += (x - Math.floor(sn * 0.5) + (sn & 0x01 == 0 ? 0.5 : 0)) * 320;

                offItem.targetX = Math.round(offItem.obj.x);
                offItem.targetY = item.targetY;
                offItem.targetA = x-1 == curAlt ? item.targetA : 0.4;
            }
        }

        camFollow.y = (curSel / loopNum) * 80;
        camFollow.y += 320;
    }

    public function exitFunc(){
        if(NewTransition.skip()) 
            return;

        MusicBeatState.changeState(new MainMenuState());
        FlxG.sound.play(Paths.lSound('ui/cancelMenu'));
    }

    public function altChange(change:Int = 0){
        if(columns <= 2) return;

        curAlt += change;
        curAlt += columns - 1;
        curAlt %= columns - 1;
        changeSelection(0);
    } 

    // # Input code

    override function keyHit(KC:KeyCode, mod:KeyModifier){
        var button = KC.deepCheck([Binds.UI_U, Binds.UI_D, Binds.UI_L, Binds.UI_R, Binds.UI_BACK]);

        if(button == -1) 
            return;

        switch(button){
            case 0, 1:
                changeSelection((button * 2) - 1);
            case 2, 3:
                altChange(((button - 2) * 2) - 1);
            case 4:
                exitFunc();
        }
    }

    override function update(elapsed:Float){
        var lerpVal = Math.pow(0.5, elapsed * 15);

        for(i in 0...Math.floor(arrGroup.length / columns)){
            for(x in 0...columns){
                var curMember = arrGroup[(i * columns) + x];

                curMember.obj.alpha = FlxMath.lerp(curMember.targetA, curMember.obj.alpha, lerpVal);
                curMember.obj.x     = FlxMath.lerp(curMember.targetX, curMember.obj.x    , lerpVal);
                curMember.obj.y     = FlxMath.lerp(curMember.targetY, curMember.obj.y    , lerpVal);
            }

            var icn:HealthIcon = arrIcons.members[i * columns];

            if(icn == null) 
                continue;

            var grpMem = arrGroup[i * columns];

            icn.x     = grpMem.obj.width + grpMem.obj.x;
            icn.y     = grpMem.obj.y + ((grpMem.obj.height - icn.height) * 0.5);
            icn.alpha = grpMem.obj.alpha;
        }

        super.update(elapsed);
    }

    // # Remove every object and reset.

    public function clearEverything(){
        for(i in 0...arrGroup.length){
            remove(arrGroup[i].obj);

            arrGroup[i].obj.destroy();
            arrGroup[i].obj = null;
        }

        arrGroup = [];
        arrIcons.clear();
    }
}