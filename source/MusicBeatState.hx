package;

import ui.CustomChartUI.ChartUI_Generic;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.FlxState;
import flixel.addons.ui.FlxUIState;
import lime.app.Application;

import ui.NewTransition;

/*
	Key handling experimental change. Instead of using OpenFL keyboard events, we use Lime's input events directly.
	Lime input events are a little different to OpenFLs but for the most part they are a drop-in replacement.

	I won't go in to much detail but I'll talk about benefits and downsides.
	
	Benefits:
	- Slightly more responsive (but it's very hard to tell the difference)
	- Allows for more advanced key detection, E.G: left and right ctrl are separate
	- Can use the key code directly without having to reference the event.

	Downsides:
	- All the key codes are different. Meaning I have to redo the settings texts in the Settings.hx file
	- You have to reference KeyCode.<Key> for key detection instead of FlxKey (major change)
	- Despite what was said earlier, it isn't exactly a drop-in replacement and a lot of code has to change.
*/

typedef DelayedEvent = {
	var endTime:Float;
	var exeFunc:Void->Void;
}

#if !debug @:noDebug #end
class MusicBeatState extends FlxUIState
{
	public static inline function curTime()
		#if desktop return Sys.time();
		#else       return Date.now().getTime() * 0.001;
		#end

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var events:Array<DelayedEvent> = [];

	public function menuMusicCheck()
	if(FlxG.sound.music == null || !FlxG.sound.music.playing) {
		Song.musicSet(Paths.menuTempo);
		FlxG.sound.playMusic(Paths.lMusic(Paths.menuMusic));
	}

	override function create()
	{
		openSubState(new NewTransition(null, false));

		persistentUpdate = true;
		FlxG.camera.bgColor.alpha = 0;

		Application.current.window.onKeyDown.add(keyHit);
		Application.current.window.onKeyUp.add(keyRel);

		super.create();
	}

	// # Input code

	public function keyHit(KC:KeyCode, mod:KeyModifier){}
	public function keyRel(KC:KeyCode, mod:KeyModifier){}

	override function destroy(){
		Application.current.window.onKeyDown.remove(keyHit);
		Application.current.window.onKeyUp.remove(keyRel);

		super.destroy();
	}

	private inline function postEvent(forward:Float, func:Void->Void)
	events.push({
		endTime: curTime() + forward,
		exeFunc: func
	});

	override function update(elapsed:Float)
	{
		Song.Position = FlxG.sound.music.time - Settings.audio_offset;

		var newStep = Math.floor(Song.Position * Song.Division);
		if (curStep != newStep && (curStep = newStep) >= -1)
			stepHit();

		// # Check if event needs to be executed.


		var i = -1;
		var cTime = curTime();
		while(++i < events.length){
			if(cTime < events[i].endTime)
				continue;

			events[i].exeFunc();
			events.splice(i--, 1);
		}

		///////////////////////

		super.update(elapsed);
	}

	public function beatHit():Void {}
	public function stepHit():Void {
		curBeat = curStep >> 2;

		if(curStep & 3 == 0) // After taking a look at compiler explorer, this is actually the fastest.
			beatHit();
	}

	private inline function execEvents()
	for(i in 0...events.length)
		events[i].exeFunc();

	public static var changeState:FlxState->Void = NewTransition.switchState;
}
