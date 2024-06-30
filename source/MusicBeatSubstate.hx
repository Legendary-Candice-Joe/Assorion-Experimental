package;

import flixel.FlxG;
import flixel.FlxSubState;
import MusicBeatState.DelayedEvent;
import lime.app.Application;

#if !debug @:noDebug #end
class MusicBeatSubstate extends FlxSubState
{
	public function new()
		super();

	private var events:Array<DelayedEvent> = [];

	private inline function postEvent(forward:Float, func:Void->Void)
	events.push({
		endTime: MusicBeatState.curTime() + forward,
		exeFunc: func
	});

	// # new input thing.

	public function keyHit(KC:KeyCode, mod:KeyModifier){}
	public function keyRel(KC:KeyCode, mod:KeyModifier){}

	override function create()
	{
		Application.current.window.onKeyDown.add(keyHit);
		Application.current.window.onKeyUp.add(keyRel);

		super.create();
	}

	override function destroy(){
		Application.current.window.onKeyDown.remove(keyHit);
		Application.current.window.onKeyUp.remove(keyRel);

		super.destroy();
	}

	//////////////////////////////////////

	override function update(elapsed:Float)
	{
		var i = -1;
		var cTime = MusicBeatState.curTime();
		while(++i < events.length){
			if(cTime < events[i].endTime)
				continue;

			events[i].exeFunc();
			events.splice(i--, 1);
		}

		super.update(elapsed);
	}
}
