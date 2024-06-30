package ui;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import misc.MenuTemplate;
import gameplay.HealthIcon;

/*
	To add an option.

	1. Add it to misc.Settings, and add a default to the default_settings.json file
	2. Add the option name to the optionSub (each line representing a category in options)
	3. Add the description for your option
	4. If the option is an integer, add it to altChange function
	5. If the option is togglable then add it to the keyHit function
*/

#if !debug @:noDebug #end
class OptionsState extends MenuTemplate
{
	static var optionSub:Array<Array<String>> = [
		['basic', 'gameplay', 'visuals', 'controls', 'changelog'],
		['start_fullscreen', 'start_volume', 'skip_splash', 'default_persist', #if desktop 'pre_caching' #end ],
		['audio_offset', 'input_offset', 'downscroll', 'ghost_tapping', 'botplay'],
		['antialiasing', #if desktop 'framerate', #end 'show_hud', 'useful_info']
	];

	static var descriptions:Array<Array<String>> = [
		[
			'Basic options for the game Window', 
			'Options for the gameplay itself', 
			'Options for visuals and effects', 
			'Change the key bindings',
			'View the history of Assorion Engine'
		],
		[
			'Start the game in fullscreen mode',
			'Change the game\'s starting volume',
			'Skip the HaxeFlixel splash screen',
			'All Graphics & text files stay in RAM. Will use more RAM but loading times decrease. DISABLE WHEN MODDING!',
			#if desktop
			'Load all assets at startup. Uses much more RAM, but loading times are basically instant'
			#end
		],
		[
			'Change your audio offset in milliseconds. Press accept to enter the offset wizard',
			'Change your keyboard offset in milliseconds. Adjusts ratings',
			'Change the scroll direction',
			'Allows pressing a key when no note has been hit, without receiving a miss',
			'Let the game press notes for you (does not count scores or health)'
		],
		[
			'Makes the graphics look smoother, but can impact performance a little',
			#if desktop
			'Changes how fast the game can run',
			#end
			'Shows your health, stats, etc in gameplay',
			'Shows FPS and memory counter'
		]
	];

	public var curSub:Int = 0;
	public var descText:FlxText;
	var bottomBlack:StaticSprite;

	override function create()
	{
		columns = 1;
		addBG(0xFFea71fd);
		menuMusicCheck();
		super.create();

		bottomBlack = new StaticSprite(0, FlxG.height - 30).makeGraphic(1280, 30, FlxColor.BLACK);
		bottomBlack.alpha = 0.6;

		descText = new FlxText(5, FlxG.height - 25, 0, "", 20);
		descText.setFormat('assets/fonts/vcr.ttf', 20, FlxColor.WHITE, LEFT);
		
		sAdd(bottomBlack);
		sAdd(descText);

		createNewList();
	}
	
	public function createNewList(?appendOption:Bool = false){
		clearEverything();
		columns = appendOption ? 2 : 1;

		for(i in 0...optionSub[curSub].length){
			pushObject(new Alphabet(0, (60 * i), optionSub[curSub][i], true));
			if(!appendOption){
				var ican:HealthIcon = new HealthIcon('settings' + (Math.floor(i / 2) + 1), false);

				if(ican.curChar == 'face')
					continue;
				if(i & 0x01 == 1) 
					ican.animation.play('losing');

				pushIcon(ican);
				continue;
			}

			// reflection. it's slow and not good. But I need it to get a variable from a string name.
			var optionStr:String = '';
			var val:Dynamic = Reflect.field(Settings, optionSub[curSub][i]);

			optionStr = Std.string(val);
			if(Std.is(val, Bool))
				optionStr = val ? 'yes' : 'no';

			pushObject(new Alphabet(0, (60 * i), optionStr, true));
		}

		changeSelection();
	}

	override public function exitFunc(){
		if(curSub > 0){
			curSub = 0;
			curSel = 0;
			createNewList(false);

			return;
		}

		SettingsManager.flush();
		super.exitFunc();
	}

	override function changeSelection(change:Int = 0){
		super.changeSelection(change);
		descText.text = descriptions[curSub][curSel];
	}

	// Add integer options here.
	override function altChange(ch:Int = 0){
		var atg:Alphabet = cast arrGroup[(curSel * 2) + 1].obj;
		switch(optionSub[curSub][curSel]){
			case 'start_volume':
				Settings.start_volume = CoolUtil.intBoundTo(Settings.start_volume + (ch * 10), 0, 100);
				atg.text = Std.string(Settings.start_volume);

			// gameplay.
			case 'audio_offset':
				Settings.audio_offset = CoolUtil.intBoundTo(Settings.audio_offset + ch, 0, 300);
				atg.text = Std.string(Settings.audio_offset);
			case 'input_offset':
				Settings.input_offset = CoolUtil.intBoundTo(Settings.input_offset + ch, 0, 300);
				atg.text = Std.string(Settings.input_offset);

			// visuals
			case 'framerate':
				Settings.framerate = SettingsManager.framerateClamp(Settings.framerate + (ch * 10));
				atg.text = Std.string(Settings.framerate);
				SettingsManager.apply();
		}
		changeSelection(0);
	}

	// Add togglable options here.
	override public function keyHit(KC:KeyCode, mod:KeyModifier){
		super.keyHit(KC, mod);

		if(!KC.hardCheck(Binds.UI_ACCEPT)) 
			return;

		switch(optionSub[curSub][curSel]){
			case 'basic':
				curSel = 0;
				curSub = 1;
			case 'gameplay':
				curSel = 0;
				curSub = 2;
			case 'visuals':
				curSel = 0;
				curSub = 3;
			case 'controls':
				if(NewTransition.skip()) return;
				MusicBeatState.changeState(new ControlsState());
				return;
			case 'changelog':
				if(NewTransition.skip()) return;
				MusicBeatState.changeState(new HistoryState());
				return;

			// basic
			case 'start_fullscreen':
				Settings.start_fullscreen = !Settings.start_fullscreen;
			case 'skip_splash':
				Settings.skip_splash = !Settings.skip_splash;
			case 'default_persist':
				Settings.default_persist = !Settings.default_persist;
				if(Settings.default_persist) 
					CoolUtil.newCanvas(true);

				SettingsManager.apply();
			case 'pre_caching':
				Settings.pre_caching = !Settings.pre_caching;

			// gameplay
			case 'audio_offset':
				if(NewTransition.skip()) return;
				MusicBeatState.changeState(new OffsetWizard());
				return;
			case 'downscroll':
				Settings.downscroll = !Settings.downscroll;
			case 'botplay':
				Settings.botplay = !Settings.botplay;
			case 'ghost_tapping':
				Settings.ghost_tapping = !Settings.ghost_tapping;

			// visuals
			case 'useful_info':
				Settings.useful_info = !Settings.useful_info;
				SettingsManager.apply();
			case 'antialiasing':
				Settings.antialiasing = !Settings.antialiasing;
			case 'show_hud':
				Settings.show_hud = !Settings.show_hud;
		}
		createNewList(true);
	}
}
