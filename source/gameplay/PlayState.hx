package gameplay;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.system.FlxSound;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;
import flixel.group.FlxGroup.FlxTypedGroup;
import lime.utils.Assets;
import gameplay.HealthIcon;
import misc.Highscore;
import ui.FreeplayState;
import ui.ChartingState;
import misc.Song.SongData;
import misc.Song.SectionData;

using StringTools;

typedef RatingData = {
	var score:Int;
	var threshold:Float;
	var name:String;
	var value:Int;
}

/*
	Note handling experimental change. This will certainly use more memory, and it is faster.
	It will on average spend more time than the default, but when there are more notes it is overall faster.
	So here I will document the change and how this new system works.

	There's 2 parts to the notes:
	- Rendering
	- Input

	========================================= Rendering
	The rendering is composed of 2 sets of arrays which contain 4 arrays (to represent each column for the notes), one for opponents and one for the player.
	For the sake of clarity, we'll call the array of arrays the "Note List", and we'll call each individual array in the note list, the "Note set".

	The first index of each note set is a integer. This integer is called the "Note Window" and defaults to 1, however if it is one then there are no notes
	in that note set. The rest of the note set will contain each note in that column that will appear in that song, but sorted backwards so the earliest notes
	go later in the array; Sorting the array backwards allows us to use a pop() which is faster than a shift() or splice().

	Every frame the index which is determined by the note set length - note window is checked to see if it can be spawned in, if it can be, then the note
	window increases and it gets added to the note group. A bit later in the frame it loops through every note in the note window backwards. So lets get
	a graphical example.

	Here the note set for the down column will look like this (↑ used to represent a note and | to represent the note window)
	In this scenario no notes have spawned in and the last note in the array will be checked to see if it can spawn in.
	[1, ↓, ↓, ↓, ↓, ↓, ↓|]

	Here is the next frame, where we can imagine that the last note can spawn in.
	As you can see, the note window at the start has increased, and all the notes in the note window will be handled.
	[2, ↓, ↓, ↓, ↓, ↓|, ↓]

	Here is yet another frame later in the song, where 3 notes in the down column have spawned in.
	3 of these notes will be managed to be scrolled down and so on.
	[4, ↓|, ↓, ↓, ↓]

	When the last note needs to be killed, we pop() the array, and decrease the note window at the same time:
	[3, ↓|, ↓, ↓]

	With that last example you can see that the note window remains in place, which allows for it to work correctly even after popping.
	With this system there are no useless condition checks; All the opponent's notes in the note list are the opponents, and all of the
	player's notes in the their note list is the player's so we never have to check.

	========================================= Input
	The input is far simpler though still a little complicated to understand. It follows a similar principle to that last ones but in general is handled a
	little differently in terms of how the array works. So once again we will use examples to show how this works as well as some plain text.

	Similar to before there is an array of 4 arrays, one for each column. Each array contains the total list of notes that will appear in that column throughout
	the duration of the song; Similar to before they will be sorted backwards so earliest goes later in the array. Also similar to before the first index is
	reserved, and is equal to when the array was last popped(), sometimes it is set to null which will discuss below. The array also will not contain any
	sustain notes.

	Every frame the game will check if the first index in the array is set to null, if it is then it will pop() the array and set the first index to what it
	ended up popping. And that is the now the 'active' note. While there is an active note the array cannot have a pop() be called on it. This means that it's
	impossible to set the note to a later one in that column, unless the first index is set to null, which can happpen under a variety of scenarios.

	Said scenarios are if the note gets hit, or gets missed. Opponent notes have no influence on the input.

	So here is the first example where the first index is null and we have five notes in the right column waiting to be hit.
	I've also labled the notes so that way we do not get confused here.
	[ , →5, →4, →3, →2, →1]

	Once that last note is in range to be hit, the first index is set to the array getting popped.
	[→1, →5, →4, →3, →2]

	When we hit that note the array becomes this:
	[ , →5, →4, →3, →2]

	Then when that last note is in range to be hit it becomes this:
	[→2, →5, →4, →3]

	We rinse and repeat this process until the array is empty. This has benefits such as forcing the input to work correctly, is actually less error-prone.
	Because it will always force us to check for the earliest note in the song (for that column) to be hit. I wouldn't call it 'faster' though, it is way more complex.

	This whole system has bugs that I'm already aware of:
	- Game crashing near the end of test song
	- Missing sustain notes sometimes causes them to get stuck
	- Multiple NPCs with notes at the same time will bug out and behave incorrectly
	- It is only 2028 NANO seconds faster
	- The data in the arrays never move around. No shifts, inserts, splices, are required.

	But these may or may not be fixed, no one under ANY circumstance should be using this fork of Assorion.
*/

#if !debug @:noDebug #end
class PlayState extends MusicBeatState
{
	public static inline var beatHalfingTime:Int = 190;
	public static inline var inputRange:Float = 1.25; // 1 and a quarter steps of input range.	
	public static var sDir:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];

	public static var songName:String = '';
	public static var SONG:SongData;
	public static var storyWeek:Int = 0;
	public static var storyPlaylist:Array<String> = [];
	public static var curDifficulty:Int = 1;
	public static var totalScore:Int = 0;

	public var strumLineY:Int;
	public var vocals:FlxSound;
	public var followPos:FlxObject;

	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var playerStrums:Array<StrumNote> = [];

	// All note / input stuff
	public var totalNotes:FlxTypedGroup<Note>;
	public var opponentNotes:Array<Array<Dynamic>> = [
		[],
		[],
		[],
		[]
	];
	public var playerNotes:Array<Array<Dynamic>> = [
		[],
		[],
		[],
		[]
	];
	public var playerNoteTimings:Array<Array<Note>> = [
		[],
		[],
		[],
		[]
	];

	// health now goes from 0 - 100, instead of 0 - 2
	public var health   :Int = 50;
	public var combo    :Int = 0;
	public var hitCount :Int = 0;
	public var missCount:Int = 0;
	public var fcValue  :Int = 0;

	public var healthBarBG:StaticSprite;
	public var healthBar:HealthBar;
	public var iconP1:HealthIcon;
	public var iconP2:HealthIcon;
	public var camHUD:FlxCamera;
	public var camGame:FlxCamera;

	public var paused:Bool = false;
	public var songScore:Int = 0;
	public var scoreTxt:FlxText;

	private var characterPositions:Array<Int> = [
		// dad
		100, 100,
		//bf
		770, 450,
		// gf
		400, 130
	];
	private var playerPos:Int = 1;
	private var allCharacters:Array<Character> = [];

	private static var stepTime:Float;
	public static var seenCutscene:Bool = false;

	public static function setData(songs:Array<String>, difficulty:Int = 1, week:Int = -1) {
		storyPlaylist = songs;
		curDifficulty = difficulty;
		storyWeek     = week;
		totalScore    = 0;

		SONG = misc.Song.loadFromJson(storyPlaylist[0], curDifficulty);
	}

	override public function create() {
		// # Camera Setup
		camGame = new FlxCamera();
		camHUD  = new FlxCamera();
		camHUD.bgColor.alpha = 0;

		followPos = new FlxObject(0, 0, 1, 1);
		followPos.setPosition(FlxG.width / 2, FlxG.height / 2);

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);
		FlxCamera.defaultCameras = [camGame];
		FlxG.camera.follow(followPos, LOCKON, 0.067);

		// # Song Setup
		songName = SONG.song.toLowerCase();
		Song.musicSet(SONG.bpm);

		vocals = new FlxSound();
		if (SONG.needsVoices)
			vocals.loadEmbedded(Paths.playableSong(songName, true));

		FlxG.sound.list.add(vocals);
		FlxG.sound.playMusic(Paths.playableSong(songName), 1, false);
		FlxG.sound.music.onComplete = endSong;
		FlxG.sound.music.stop();

		// # BG & UI setup
		playerPos = SONG.activePlayer;
		handleStage();

		strumLineY = Settings.downscroll ? FlxG.height - 150 : 50;
		strumLineNotes = new FlxTypedGroup<StrumNote>();
		totalNotes     = new FlxTypedGroup<Note>();
		add(strumLineNotes);
		add(totalNotes);

		generateChart();
		for(i in 0...SONG.playLength)
			generateStrumArrows(i, SONG.activePlayer == i);

		// # Score setup
		for(i in 0...possibleScores.length)
			FlxGraphic.fromAssetKey(Paths.lImage('gameplay/${possibleScores[i].name}'), false, null, true).persist = true;

		ratingSpr = new StaticSprite(0,0);
		ratingSpr.scale.set(0.7, 0.7);
		ratingSpr.alpha = 0;
		add(ratingSpr);

		for(i in 0...3){
			var sRef = comboSprs[i] = new StaticSprite(0,0);
			sRef.frames = Paths.lSparrow('gameplay/comboNumbers');
			for(i in 0...10) 
				sRef.animation.addByPrefix('$i', '${i}num', 1, false);
			sRef.animation.play('0');
			sRef.centerOrigin();
			sRef.screenCenter();
			sRef.y += 120;
			sRef.x += (i - 1) * 60;
			sRef.scale.set(0.6, 0.6);
			sRef.alpha = 0;
			add(sRef);
		}

		// # UI Setup
		var baseY:Int = Settings.downscroll ? 80 : 650;

		healthBarBG = new StaticSprite(0, baseY).loadGraphic(Paths.lImage('gameplay/healthBar'));
		healthBarBG.screenCenter(X);
		healthBarBG.scrollFactor.set();

		var healthColours:Array<Int> = [0xFFFF0000, 0xFF66FF33];
		healthBar = new HealthBar(healthBarBG.x + 4, healthBarBG.y + 4, RIGHT_TO_LEFT, Std.int(healthBarBG.width - 8), Std.int(healthBarBG.height - 8));
		healthBar.scrollFactor.set();
		healthBar.createFilledBar(healthColours[0], healthColours[1]);

		scoreTxt = new FlxText(0, baseY + 40, 0, '', 20);
		scoreTxt.setFormat("assets/fonts/vcr.ttf", 16, 0xFFFFFFFF, CENTER, OUTLINE, 0xFF000000);
		scoreTxt.scrollFactor.set();
		scoreTxt.screenCenter(X);

		iconP1 = new HealthIcon(SONG.characters[1], true);
		iconP2 = new HealthIcon(SONG.characters[0], false);
		iconP1.y = baseY - (iconP1.height / 2);
		iconP2.y = baseY - (iconP2.height / 2);

		// # Add to cameras
		strumLineNotes.cameras = [camHUD];
		totalNotes.cameras     = [camHUD];
		if(Settings.show_hud){
			add(healthBarBG);
			add(healthBar);
			add(scoreTxt);
			add(iconP1);
			add(iconP2);

			healthBar.cameras =
			healthBarBG.cameras =
			iconP1.cameras =
			iconP2.cameras = 
			scoreTxt.cameras = [camHUD];
		}

		stepTime = -16 - (((SONG.beginTime * 1000) + Settings.audio_offset) * Song.Division);
		updateHealth(0);

		super.create();

		var stateHolder:Array<DialogueSubstate> = [];
		var seenCut:Bool = DialogueSubstate.crDialogue(camHUD, startCountdown, '$songName/dialogue.txt', this, stateHolder);

		postEvent(SONG.beginTime + 0.1, startCountdown);
		if(seenCut) 
			return;

		events.pop();

		postEvent(0.8, function(){
			pauseAndOpenState(stateHolder[0]);
		});
	}

	public inline function addCharacters() {
		for(i in 0...SONG.characters.length)
			allCharacters.push(new Character(characterPositions[i * 2], characterPositions[(i * 2) + 1], SONG.characters[i], i == 1));
		
		for(i in 0...SONG.characters.length)
			add(allCharacters[SONG.renderBackwards ? i : (SONG.characters.length - 1) - i]);
	}

	// put things like gf and bf positions here.
	public inline function handleStage() {
		switch(SONG.stage){
			case 'stage', '':
				FlxG.camera.zoom = 0.9;

				var bg:StaticSprite = new StaticSprite(-600, -200).loadGraphic(Paths.lImage('stages/stageback'));
					bg.setGraphicSize(Std.int(bg.width * 2));
					bg.updateHitbox();
					bg.scrollFactor.set(0.9, 0.9);
				add(bg);
				var stageFront:StaticSprite = new StaticSprite(-650, 600).loadGraphic(Paths.lImage('stages/stagefront'));
					stageFront.setGraphicSize(Std.int(stageFront.width * 2.2));
					stageFront.updateHitbox();
					stageFront.scrollFactor.set(0.9, 0.9);
				add(stageFront);
				var curtainLeft:StaticSprite = new StaticSprite(-500, -165).loadGraphic(Paths.lImage('stages/curtainLeft'));
					curtainLeft.setGraphicSize(Std.int(curtainLeft.width * 1.8));
					curtainLeft.updateHitbox();
					curtainLeft.scrollFactor.set(1.3, 1.3);
				add(curtainLeft);
				var curtainRight:StaticSprite = new StaticSprite(1406, -165).loadGraphic(Paths.lImage('stages/curtainRight'));
					curtainRight.setGraphicSize(Std.int(curtainRight.width * 1.8));
					curtainRight.updateHitbox();
					curtainRight.scrollFactor.set(1.3, 1.3);
				add(curtainRight);

				addCharacters();
		}
	}

	private inline function generateChart():Void {
		for(section in SONG.notes)
			for(fNote in section.sectionNotes){
				var time:Float = fNote[0];
				var noteData :Int = Std.int(fNote[1]);
				var susLength:Int = Std.int(fNote[2]);
				var player   :Int = CoolUtil.intBoundTo(Std.int(fNote[3]), 0, SONG.playLength - 1);
				var ntype    :Int = Std.int(fNote[4]);

				var newNote = new Note(time, noteData, ntype, false, false);
				newNote.scrollFactor.set();
				newNote.player = player;

				if(newNote.player == playerPos){
					playerNotes      [newNote.noteData].insert(0, newNote);
					playerNoteTimings[newNote.noteData].insert(0, newNote);
				} else
					opponentNotes[newNote.noteData].insert(0, newNote);

				if(susLength > 1)
					for(i in 0...susLength+1){
						var susNote = new Note(time + i + 0.5, noteData, ntype, true, i == susLength);
						susNote.scrollFactor.set();
						susNote.player = player;

						(susNote.player == playerPos ? playerNotes : opponentNotes)[susNote.noteData].insert(0, susNote);
					}
			}
		
		for(i in 0...Note.keyCount){
			opponentNotes    [i].sort((A,B) -> Std.int(B.strumTime - A.strumTime));
			playerNotes      [i].sort((A,B) -> Std.int(B.strumTime - A.strumTime));
			playerNoteTimings[i].sort((A,B) -> Std.int(B.strumTime - A.strumTime));
			
			opponentNotes[i]    .insert(0, cast(1, Int));
			playerNotes[i]      .insert(0, cast(1, Int));
			playerNoteTimings[i].insert(0, null);
		}
	}

	private function generateStrumArrows(player:Int, playable:Bool):Void
	for (i in 0...Note.keyCount)
	{
		var babyArrow:StrumNote = new StrumNote(0, strumLineY - 10, i, player);
		babyArrow.alpha = 0;

		strumLineNotes.add(babyArrow);
		if(playable) 
			playerStrums.push(babyArrow);
	}

	function startCountdown():Void {
		for(i in 0...strumLineNotes.length)
			FlxTween.tween(strumLineNotes.members[i], {alpha: 1, y: strumLineNotes.members[i].y + 10}, 0.5, {startDelay: ((i % Note.keyCount) + 1) * 0.2});

		var introSprites:Array<StaticSprite> = [];
		var introSounds:Array<FlxSound>   = [];
		var introAssets :Array<String>    = [
			'ready', 'set', 'go', '',
			'intro3', 'intro2', 'intro1', 'introGo'
		]; 
		for(i in 0...4){
			var snd:FlxSound = new FlxSound().loadEmbedded(Paths.lSound('gameplay/' + introAssets[i + 4]));
				snd.volume = 0.6;
			introSounds[i] = snd;

			if(i > 3) continue;

			var spr:StaticSprite = new StaticSprite().loadGraphic(Paths.lImage('gameplay/${ introAssets[i] }'));
				spr.scrollFactor.set();
				spr.screenCenter();
				spr.alpha = 0;
				spr.active = false;
			add(spr);

			introSprites[i+1] = spr;
		}

		var swagCounter:Int = 0;
		var countTickFunc:Void->Void = function(){
			if(swagCounter >= 4){
				FlxG.sound.music.play();
				FlxG.sound.music.volume = 1;
				Song.Position = -Settings.audio_offset;

				vocals.play();
				vocals.time = FlxG.sound.music.time = 0;
				return;
			}
			for(pc in allCharacters)
				pc.dance();

			stepTime = (swagCounter - 4) * 4;
			stepTime -= Settings.audio_offset * Song.Division;

			introSounds[swagCounter].play();
			if(introSprites[swagCounter] != null)
				introSpriteTween(introSprites[swagCounter], 3, Song.StepCrochet, true);

			swagCounter++;
		}
		for(i in 0...5)
			postEvent(((Song.Crochet * (i + 1)) + Settings.audio_offset) * 0.001, countTickFunc);
	}

	override public function update(elapsed:Float) if(!paused) {
		var scaleVal = CoolUtil.boundTo(iconP1.scale.x - (elapsed * 2), 1, 1.2);
		iconP1.scale.set(scaleVal, scaleVal);
		iconP2.scale.set(scaleVal, scaleVal);

		if(seenCutscene)
			stepTime += (elapsed * 1000) * Song.Division;

		// All this is to handle everything to do with notes
		for(i in 0...Note.keyCount){
			// Note spawning:
			var noteSet = opponentNotes[i];
			var window:Int = noteSet[0];

			if (noteSet.length != 1 && noteSet[noteSet.length - window].strumTime - stepTime < 16){
				totalNotes.add(noteSet[noteSet.length - window]);
				++noteSet[0];
			}

			noteSet = playerNotes[i];
			window = noteSet[0];
			if(noteSet.length != 1 && noteSet[noteSet.length - window].strumTime - stepTime < 16){
				totalNotes.add(noteSet[noteSet.length - window]);
				++noteSet[0];
			}

			// Input checks:
			noteSet = playerNoteTimings[i];
			if(noteSet.length != 1)
				if(noteSet[noteSet.length - 1].strumTime - stepTime < inputRange && noteSet[0] == null /*|| playerNoteTimings[i][0].strumTime - stepTime <= -inputRange)*/)
					noteSet[0] = noteSet.pop();

			// Player note handling:
			var len:Int = playerNotes[i].length - 1;
			for(m in 0...window-1){
				var daNote:Note = playerNotes[i][len - m];
				var nDiff:Float = stepTime - daNote.strumTime;
				var strumRef = playerStrums[i];

				daNote.y = (Settings.downscroll ? 45 : -45) * nDiff * SONG.speed;
				daNote.y += strumRef.y + daNote.offsetY;
				daNote.x = strumRef.x + daNote.offsetX;
				daNote.angle = strumRef.angle;

				if(nDiff > inputRange){
					if(daNote.curType.mustHit)
						missNote(i);

					destroyNote(daNote, 1);
					continue;
				}

				if(daNote.isSustainNote && Math.abs(nDiff) < 0.8 && keysPressed[i]){
					hitNote(daNote);
					destroyNote(daNote, 0);
				}
			}

			//Opponent note handling:
			len = opponentNotes[i].length - 1;
			window = opponentNotes[i][0];

			for(m in 0...window-1){
				var daNote:Note = opponentNotes[i][len - m];
				var nDiff:Float = stepTime - daNote.strumTime;
				var strumRef = strumLineNotes.members[i + (Note.keyCount * daNote.player)];

				daNote.y = (Settings.downscroll ? 45 : -45) * nDiff * SONG.speed;
				daNote.y += strumRef.y + daNote.offsetY;
				daNote.x = strumRef.x + daNote.offsetX;
				daNote.angle = strumRef.angle;

				if(stepTime >= daNote.strumTime && daNote.curType.mustHit){
					allCharacters[daNote.player].playAnim('sing' + sDir[i]);
					strumRef.playAnim(2);
					strumRef.pressTime = Song.StepCrochet * 0.001;
					vocals.volume = 1;
		
					--opponentNotes[i][0];
					opponentNotes[i].pop();
					totalNotes.remove(daNote);
				}
			}
		}

		super.update(elapsed);
	}

	override function beatHit() {
		super.beatHit();

		iconP1.scale.set(1.2,1.2);
		iconP2.scale.set(1.2,1.2);
		
		#if (flixel < "5.4.0")
		FlxG.camera.followLerp = (1 - Math.pow(0.5, FlxG.elapsed * 6)) * Main.framerateDivision;
		#end

		var sec:SectionData = SONG.notes[curBeat >> 2]; // "curBeat >> 2" is the same as "Math.floor(curBeat / 4)", but faster
		if(curBeat & 3 == 0 && FlxG.sound.music.playing){
			// prevent the Int from being null, if it is it will just be 0.
			var tFace:Int = sec != null ? cast(sec.cameraFacing, Int) : 0;

			var char = allCharacters[CoolUtil.intBoundTo(tFace, 0, SONG.playLength - 1)];
			followPos.x = char.getMidpoint().x + char.camOffset[0];
			followPos.y = char.getMidpoint().y + char.camOffset[1];
		}

		if(curBeat % (Math.floor(SONG.bpm / beatHalfingTime) + 1) == 0)
			for(pc in allCharacters)
				pc.dance();
	}
	override function stepHit() {
		super.stepHit();

		if(FlxG.sound.music.playing)
			stepTime = ((Song.Position * Song.Division) + stepTime) * 0.5;
	}

	// THIS IS WHAT UPDATES YOUR SCORE AND HEALTH AND STUFF!

	private static inline var iconSpacing:Int = 52;
	public function updateHealth(change:Int) {
		if(Settings.botplay)
			scoreTxt.text = 'Botplay';
		else {
			var fcText:String = ['?', 'SFC', 'GFC', 'FC', '(Bad) FC', 'SDCB', 'Clear'][fcValue];
			var accuracyCount:Float = CoolUtil.boundTo(Math.floor((songScore * 100) / ((hitCount + missCount) * 3.5)) * 0.01, 0, 100);

			scoreTxt.text = 'Notes Hit: $hitCount | Notes Missed: $missCount | Accuracy: $accuracyCount% - $fcText | Score: $songScore';
		} 
		scoreTxt.screenCenter(X);

		health = CoolUtil.intBoundTo(health + change, 0, 100);
		healthBar.percent = health;
		
		var calc = (0 - ((health - 50) * 0.01)) * healthBar.width;
		iconP1.x = 565 + (calc + iconSpacing); 
		iconP2.x = 565 + (calc - iconSpacing);
		iconP1.changeState(health < 20);
		iconP2.changeState(health > 80);

		if(health != 0)
			return;

		remove(allCharacters[playerPos]);
		pauseAndOpenState(new GameOverSubstate(allCharacters[playerPos], camHUD, this));
	}

	function hitNote(note:Note):Void {
		if(!note.curType.mustHit){
			missNote(note.noteData);
			return;
		}

		playerStrums[note.noteData].playAnim(2);
		allCharacters[playerPos].playAnim('sing' + sDir[note.noteData]);
		vocals.volume = 1;

		if(!note.isSustainNote){
			hitCount++;
			popUpScore(note.strumTime);
		}
		
		updateHealth(5);
	}

	function missNote(direction:Int = 1):Void {
		combo = 0;
		songScore -= 50;
		missCount++;
		vocals.volume = 0.5; // Halving the Vocals, instead of completely muting them.

		FlxG.sound.play(Paths.lSound('gameplay/missnote' + (Math.round(Math.random() * 2) + 1)), 0.2);

		allCharacters[playerPos].playAnim('sing' + sDir[direction] + 'miss');
		fcValue = missCount >= 10 ? 6 : 5;

		updateHealth(-10);
	}

	// For anything that would require keyboard input, please put it here, not update.

	//public var hittableNotes:Array<Note> = [null, null, null, null];
	public var keysPressed:Array<Bool>   = [false, false, false, false];
	public var keysArray:Array<Array<Int>> = [Binds.NOTE_LEFT, Binds.NOTE_DOWN, Binds.NOTE_UP, Binds.NOTE_RIGHT];
	override function keyHit(KC:KeyCode, mod:KeyModifier) if(!paused) {
		// Assorions "Fast" input system
		var nkey = KC.deepCheck(keysArray);
		if(nkey >= 0 && !keysPressed[nkey] && !Settings.botplay){
			var strumRef = playerStrums[nkey];
			keysPressed[nkey] = true;
			
			if(playerNoteTimings[nkey][0] != null){
				hitNote(playerNoteTimings[nkey][0]);
				destroyNote(playerNoteTimings[nkey][0], 0);

				strumRef.pressTime = Song.StepCrochet * 0.00075;
			} else if(strumRef.pressTime <= 0){
				strumRef.playAnim(1);
				if(!Settings.ghost_tapping)
					missNote(nkey);
			}

			return;
		}

		var k = KC.deepCheck([Binds.UI_ACCEPT, Binds.UI_BACK, [FlxKey.SEVEN], [FlxKey.F12] ]);
		
		switch(k){
			case 0, 1:
				if(seenCutscene)
					pauseAndOpenState(new PauseSubState(camHUD, this));
			case 2:
				MusicBeatState.changeState(new ChartingState());
				seenCutscene = false;
			case 3:
				misc.Screenshot.takeScreenshot();
		}
	}
	override public function keyRel(KC:KeyCode, mod:KeyModifier) {
		var nkey = KC.deepCheck(keysArray);
		if (nkey == -1 || paused) 
			return;

		keysPressed[nkey] = false;
		playerStrums[nkey].playAnim();
	}

	public static var possibleScores:Array<RatingData> = [
		{
			score: 350,
			threshold: 0,
			name: 'sick',
			value: 1
		},
		{
			score: 200,
			threshold: 0.45,
			name: 'good',
			value: 2
		},
		{
			score: 100,
			threshold: 0.65,
			name: 'bad',
			value: 3
		},
		{
			score: 25,
			threshold: 1,
			name: 'superbad',
			value: 4
		}
	];
	private var ratingSpr:StaticSprite;
	private var previousValue:Int;
	private var comboSprs:Array<StaticSprite> = [];
	private var scoreTweens:Array<FlxTween> = [];
	private inline function popUpScore(strumtime:Float):Void {
		var noteDiff:Float = Math.abs(strumtime - (stepTime - (Settings.input_offset * Song.Division)));
		var pscore:RatingData = null;

		for(i in 0...possibleScores.length)
			if(noteDiff >= possibleScores[i].threshold){
				pscore   = possibleScores[i];
			} else break;

		songScore += pscore.score;
		combo = pscore.score > 50 && combo < 1000 ? combo + 1 : 0;
		if(pscore.value > fcValue)
			fcValue = pscore.value;

		// Everything below here is to handle graphics.

		if(scoreTweens[0] != null)
			for(i in 0...4) scoreTweens[i].cancel();

		if(previousValue != pscore.value){
			ratingSpr.loadGraphic(Paths.lImage('gameplay/' + pscore.name));
			ratingSpr.centerOrigin();
			previousValue = pscore.value;
		}
		ratingSpr.screenCenter();

		var comsplit:Array<String> = Std.string(combo).split('');
		for(i in 0...3){
			var sRef = comboSprs[i];
			sRef.animation.play((3 - comsplit.length <= i) ? comsplit[i + (comsplit.length - 3)] : '0');
			sRef.screenCenter(Y);
			sRef.y += 120;

			scoreTweens[i+1] = introSpriteTween(sRef, 3, Song.StepCrochet * 0.5, false);
		}
		scoreTweens[0] = introSpriteTween(ratingSpr, 3,  Song.StepCrochet * 0.5, false);
	}

	function endSong():Void {
		FlxG.sound.music.volume = 0;
		vocals.volume = 0;
		paused = true;

		Highscore.saveScore(SONG.song, songScore, curDifficulty);

		if (storyWeek == -1){
			CoolUtil.exitPlaystate();
			return;
		}
		
		totalScore += songScore;
		storyPlaylist.shift();

		if (storyPlaylist.length <= 0){
			Highscore.saveScore('week-$storyWeek', totalScore, curDifficulty);
			CoolUtil.exitPlaystate();
			return;
		}

		seenCutscene = false;
		SONG = misc.Song.loadFromJson(storyPlaylist[0], curDifficulty);
		FlxG.sound.music.stop();
		FlxG.resetState();
	}

	var lastOpenTime:Float;
	function pauseAndOpenState(state:MusicBeatSubstate) {
		paused = true;
		lastOpenTime = MusicBeatState.curTime();
		FlxG.sound.music.pause();
		vocals.pause();

		openSubState(state);
	}

	inline function destroyNote(note:Note, act:Int) {
		note.typeAction(act);
		
		--playerNotes[note.noteData][0];
		playerNotes[note.noteData].pop();
		totalNotes.remove(note);

		playerNoteTimings[note.noteData][0] = null;
		note.destroy();
	}

	private inline function introSpriteTween(spr:StaticSprite, steps:Int, delay:Float = 0, destroy:Bool):FlxTween {
		spr.alpha = 1;
		return FlxTween.tween(spr, {y: spr.y + 10, alpha: 0}, (steps * Song.StepCrochet) / 1000, { ease: FlxEase.cubeInOut, startDelay: delay * 0.001,
			onComplete: function(twn:FlxTween)
			{
				if(destroy)
					spr.destroy();
			}
		});
	}

	override function onFocusLost() {
		super.onFocusLost();

		if(!paused && seenCutscene)
			pauseAndOpenState(new PauseSubState(camHUD, this));
	}
}
