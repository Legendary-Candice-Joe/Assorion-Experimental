package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.group.FlxGroup.FlxTypedGroup;
import misc.Song;
import misc.Highscore;
import ui.ChartingState;
import misc.MenuTemplate;
import gameplay.PlayState;

using StringTools;

typedef StoryData = {
	var portrait:String;
	var weekAsset:String;
	var songs:Array<String>;
	var topText:String;
}

#if !debug @:noDebug #end
class StoryMenuState extends MenuTemplate
{
	public static var curDif:Int = 1;

	static var weekData:Array<StoryData> = [
		{
			portrait: 'storyportrait',   // Picture shown on the right
			weekAsset: '1',              // Graphic used for selecting (doesn't have to be a number)
			songs: ['tutorial', 'demo'], 
			topText: 'THIS IS A TEST'
		}
	];

	public var weekBG:FlxSprite;
	public var topText:FlxText;
	public var trackList:FlxText;

	var arrowSpr1:StaticSprite;
	var arrowSpr2:StaticSprite;
	var diffImage:StaticSprite;

	public static inline var selectColour:Int = 0xFF00FFFF;
	public static inline var whiteColour:Int  = 0xFFFFFFFF;

	override function create(){
		super.create();
		menuMusicCheck();

		for(i in 0...weekData.length){
			var weekGraphic:FlxSprite = new FlxSprite(0,0).loadGraphic(Paths.lImage('storymenu/week-' + weekData[i].weekAsset));
			weekGraphic.updateHitbox();
			weekGraphic.centerOrigin();
			weekGraphic.scale.set(0.7, 0.7);
			weekGraphic.antialiasing = Settings.antialiasing;
			weekGraphic.offset.x += 75;

			pushObject(weekGraphic);
		}

		var topBlack:StaticSprite = new StaticSprite(0,0).makeGraphic(640, 20, FlxColor.fromRGB(25,25,25));
		topText = new FlxText(0, 2, 0, "1234567890ABCDEFG", 18);
		topText.setFormat('assets/fonts/vcr.ttf', 18, FlxColor.GRAY, CENTER);
		topText.screenCenter(X);
		topText.x -= 320;
		sAdd(topBlack);
		sAdd(topText);

		// bruh
		arrowSpr1 = new StaticSprite(640 - 50, 30).loadGraphic(Paths.lImage('storymenu/arrow'));
		arrowSpr1.updateHitbox();
		arrowSpr1.centerOrigin();
		arrowSpr1.scale.set(0.7,0.7);
		arrowSpr2 = new StaticSprite(640 - 330, 30).loadGraphic(Paths.lImage('storymenu/arrow'));
		arrowSpr2.flipX = true;
		arrowSpr2.updateHitbox();
		arrowSpr2.centerOrigin();
		arrowSpr2.scale.set(0.7, 0.7);

		diffImage = new StaticSprite(640, 45);
		diffImage.scale.set(0.7, 0.7);

		trackList = new FlxText(0, 110, 0, "Tracks", 32);
		trackList.setFormat('assets/fonts/vcr.ttf', 32, CENTER);
		trackList.color = 0xFFE55777;
		trackList.screenCenter(X);
		trackList.x -= 167.5;
		sAdd(arrowSpr1);
		sAdd(arrowSpr2);
		sAdd(diffImage);
		sAdd(trackList);
	}

	var leaving:Bool = false;
	override function keyHit(KC:KeyCode, mod:KeyModifier){
		super.keyHit(KC, mod);

		if(!KC.hardCheck(Binds.UI_ACCEPT)) 
			return;

		if(leaving){
			execEvents();
			NewTransition.skip();
			return;
		}

		leaving = true;

		// can't just use the songs array outright.
		// otherwise it will end up deleting them.
		var nSongs:Array<String> = [];
		for(s in weekData[curSel].songs)
			nSongs.push(s);

		FlxG.sound.play(Paths.lSound('ui/confirmMenu'));
		PlayState.setData(nSongs, curDif, curSel);

		for(i in 0...8)
			postEvent(i / 8, function(){
				arrGroup[curSel].obj.color = (i & 0x01 == 0 ? whiteColour : selectColour);
			});

		// SWITCH!
		postEvent(1, function(){
			MusicBeatState.changeState(new PlayState());
			
			if (FlxG.sound.music.playing)
				FlxG.sound.music.stop();
		});
	}

	public function changeDiff(to:Int, showArr:Bool){
		curDif = ((curDif + to) + CoolUtil.diffNumb) % CoolUtil.diffNumb;

		diffImage.loadGraphic(Paths.lImage('storymenu/' + CoolUtil.diffString(curDif, 1).toLowerCase()));
		diffImage.centerOrigin();
		diffImage.updateHitbox();
		diffImage.screenCenter(X);
		diffImage.x -= 167.5;

		topText.text = weekData[curSel].topText + ' - ${Highscore.getScore('week-$curSel', curDif)}';
		topText.screenCenter(X);
		topText.x -= 320;

		if(!showArr) return;

		var arrow = [arrowSpr2, arrowSpr1][to >= 0 ? 1 : 0];
		arrow.color = selectColour;
		arrow.scale.set(0.6, 0.6);
		postEvent(0.08, function(){
			arrow.color = whiteColour;
			arrow.scale.set(0.7, 0.7);
		});
	}
	override function changeSelection(to:Int = 0){
		arrGroup[curSel].obj.color = whiteColour;

		super.changeSelection(to);
		changeDiff(0, false);

		arrGroup[curSel].obj.color = selectColour;

		trackList.text = 'Tracks:\n';
		for(i in 0...weekData[curSel].songs.length)
			trackList.text += weekData[curSel].songs[i].toUpperCase() + '\n';

		trackList.screenCenter(X);
		trackList.x -= 167.5;

		// handle fades

		var oldRef:FlxSprite = weekBG;
		weekBG = new FlxSprite(640, 0).loadGraphic(Paths.lImage('storymenu/' + weekData[curSel].portrait));
		weekBG.antialiasing = Settings.antialiasing;
		sAdd(weekBG);

		if(oldRef == null) return;

		weekBG.alpha = 0;
		FlxTween.tween(weekBG, {alpha: 1}, 0.2);
		postEvent(0.21, function(){
			if(oldRef == null) return;

			oldRef.destroy();
			oldRef = null;
			remove(oldRef);
		});
	}
	override function altChange(to:Int = 0)
		changeDiff(to, true);
}