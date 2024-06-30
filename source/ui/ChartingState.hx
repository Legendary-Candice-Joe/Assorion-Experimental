package ui;

import haxe.Json;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import openfl.display.BitmapData;
import openfl.events.KeyboardEvent;
import openfl.geom.Rectangle;
import openfl.events.MouseEvent;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import gameplay.Note;
import gameplay.PlayState;
import misc.Song;
import ui.CustomChartUI;
#if desktop
import sys.io.File;
#end
import gameplay.HealthIcon;
import flixel.tweens.FlxTween;

using StringTools;

#if !debug @:noDebug #end
class ChartingState extends MusicBeatState {
    public static var uiColours:Array<Array<Int>> = [
        [155, 100, 160], // dark
        [200, 120, 210], // light
        [240, 150, 250], // 3d light
        [170, 170, 200], // note select colour
        [20,  45,  55 ], // swamp green background colour
    ];
    public static var gridColours:Array<Array<Array<Int>>> = [
        [[255, 200, 200], [255, 215, 215]], // Red
        [[200, 200, 255], [215, 215, 255]], // Blue
        [[240, 240, 200], [240, 240, 215]], // Yellow / White
        [[200, 255, 200], [215, 255, 215]], // Green
    ];
    public static inline var defaultGridSize:Int = 40;
    public var gridSize:Int;

    public static var zooms:Array<Float> = [0.5, 0.75, 1, 1.5, 2, 3, 4, 6, 8];
    public var curZoom:Int = 2;

    public var selectedNotes:Array<Array<Dynamic>> = [];
    public static var curNoteType:Int = 0;

    var gridLayer:FlxTypedGroup<StaticSprite>;
    var noteHighlight:StaticSprite;
    var blueSelectBox:StaticSprite;

    public var curSec:Int = 0;
    public var musicLine:StaticSprite;

    public var notes:FlxTypedGroup<Note>;

    public var camUI:FlxCamera;
    public var camGR:FlxCamera;

    var uiBG:ChartUI_Generic;
    public var uiElements:FlxTypedSpriteGroup<ChartUI_Generic>;
    public static var overlappingElement:ChartUI_Generic;
    public static var currentElement:ChartUI_Generic;

    private var vocals:FlxSound;
    private var song:SongData;

    public var warningTxt:FlxText;

    override public function create(){
        if(FlxG.sound.music.playing){
            FlxG.sound.music.pause();
            FlxG.sound.music.time = 0;

            FlxG.sound.music.onComplete = function(){
                FlxG.sound.music.pause();
                FlxG.sound.music.time = 0;
            };
        }
        song = PlayState.SONG;

        // # cam code

        camUI = new FlxCamera();
        camGR = new FlxCamera(100,50, 0, 0);
        camGR.bgColor.alpha = camUI.bgColor.alpha = 0;

        FlxG.cameras.reset(camUI);
		FlxG.cameras.add(camGR);
		FlxCamera.defaultCameras = [camUI];

        // # create bg

        var bgspr:StaticSprite = new StaticSprite(0,0).loadGraphic(Paths.lImage('ui/menuDesat'));
            bgspr.screenCenter();
            bgspr.color = CoolUtil.cfArray(uiColours[4]);
        add(bgspr);

        // # create grid

        gridSizeCalc();
        gridLayer = new FlxTypedGroup<StaticSprite>();
        noteHighlight = new StaticSprite(0,0).makeGraphic(gridSize, gridSize, 0xFFFFFFFF);
        add(gridLayer);
        add(noteHighlight);

        // # UI

        uiBG = new ChartUI_Generic(camGR.x + camGR.width + 25, 0, 520, 600, false, '');
        uiBG.drawSquare(0,   0, 410, 600);
        uiBG.drawSquare(410, 0, 110, 600);
        uiBG.screenCenter(Y);
        uiElements = new FlxTypedSpriteGroup<ChartUI_Generic>();
        uiElements.y = uiBG.y + 10;

        add(uiBG);
        add(uiElements);

        tabButtons.push(new ChartUI_Button(400, uiBG.y    , 110, 30, createSongUI, 'SONG'));
        tabButtons.push(new ChartUI_Button(400, uiBG.y+30 , 110, 30, createCharUI, 'PLAYERS'));
        tabButtons.push(new ChartUI_Button(400, uiBG.y+60 , 110, 30, createSecUI , 'SECTION'));
        tabButtons.push(new ChartUI_Button(400, uiBG.y+570, 110, 30, createInfoUI, 'HELP'));

        createSongUI();

        // # create line and notes

        makeGrid();

        notes     = new FlxTypedGroup<Note>();
        musicLine = new StaticSprite(0, 0).makeGraphic(960, 4, 0xFFFFFFFF);
        add(notes);
        add(musicLine);

        noteHighlight.cameras =
        gridLayer.cameras =
        notes    .cameras =
        musicLine.cameras = [camGR];

        // # Creates vocals.

        vocals = new FlxSound();
		if (song.needsVoices)
			vocals.loadEmbedded(Paths.playableSong(PlayState.songName, true));

        vocals.time = 0;
		FlxG.sound.list.add(vocals);
        FlxG.mouse.visible = true;

        reloadNotes();

        // # Create Selection box

        blueSelectBox = new StaticSprite(-1,-1).makeGraphic(1,1, FlxColor.fromRGB(140,225,255));
		blueSelectBox.origin.set(0,0);
		blueSelectBox.alpha = 0.55;
        blueSelectBox.cameras = [camGR];
		add(blueSelectBox);

        FlxG.stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveEvent);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownEvent);
        FlxG.stage.addEventListener(MouseEvent.MOUSE_UP  , mouseUpEvent);

        super.create();

        warningTxt = new FlxText(uiBG.x, uiBG.y - 30, 0, '', 12);
        warningTxt.alpha = 0;
        add(warningTxt);
    }

    public inline function gridSizeCalc() 
        gridSize = song.playLength < 5 ? defaultGridSize : Math.floor(defaultGridSize * (4 / song.playLength));

    public inline function pauseSong(){
        FlxG.sound.music.pause();
        vocals.pause();
    }
    public inline function changeSec(changeTo:Int){
        curSec = CoolUtil.intBoundTo(changeTo, 0, song.notes.length + 1);
        expandCheck();
        reloadNotes();

        if(currentTab == 2)
            createSecUI();
    }

    // for changing zoom level and/or changing amount of singing characters
    public function makeGrid(){
        var gridSprite:StaticSprite = new ChartUI_Grid(gridSize, gridSize, Note.keyCount * (song.playLength), Math.floor(16 * zooms[curZoom]), (curZoom + 1) % 2 + 3);

        gridLayer.clear();
        gridLayer.add(gridSprite);

        for(i in 0...song.playLength){
            if(song.characters.length - 1 < i) break;

            var tmpIcon = new HealthIcon(song.characters[i]);
            tmpIcon.x = gridSize * i * Note.keyCount + gridSize;
            tmpIcon.y = gridSprite.height + 10;
            tmpIcon.scale.set(0.5, 0.5);
            tmpIcon.updateHitbox();

            gridLayer.add(tmpIcon);
        }

        camGR.width  = Math.round(gridSprite.width);
        camGR.height = Math.round(gridSprite.height + 85);

        uiBG.x = camGR.width + camGR.x + 25;
        uiElements.x = uiBG.x + 10;
        noteHighlight.setGraphicSize(gridSize);
        noteHighlight.updateHitbox();
    }

    // # Keyboard input

    private var holdingControl:Bool = false;
    private var holdingShift:Bool   = false;
    override function keyHit(KC:KeyCode, mod:KeyModifier){
        var key:Int = KC;

        trace(KC);

        if (currentElement != null){
            key == KeyCode.RETURN ? currentElement.forceExit() : currentElement.keyInsert(key);
            return;
        }

        if(mod.shiftKey){
            holdingShift = true;
            return;
        }

        // ONLY FOR CONTROL. READ AHEAD!

        if(mod.ctrlKey){
            var T:Int = key.deepCheck([
                [KeyCode.J],
                [KeyCode.L],
                [KeyCode.I],
                [KeyCode.K],

                [KeyCode.C],
                [KeyCode.V],
                [KeyCode.A]
            ]);

            switch(T){
                case 0:
                    for(nt in selectedNotes){
                        nt[1]--;
                        if (nt[1] < 0) {
                            nt[1] = Note.keyCount - 1;
                            nt[3] = ((nt[3] - 1) + song.playLength) % song.playLength;
                        }
                    }
                case 1:
                    for(nt in selectedNotes){
                        nt[1]++;
                        if (nt[1] > Note.keyCount - 1){
                            nt[1] = 0;
                            nt[3] = (nt[3] + 1) % song.playLength;
                        }
                    }
                case 2:
                    for(nt in selectedNotes){
                        song.notes[Math.floor(nt[0] / 16)].sectionNotes.remove(nt);
                        nt[0]--;
                        if(nt[0] < 0) nt[0] = 0;
                        song.notes[Math.floor(nt[0] / 16)].sectionNotes.push(nt);
                    }
                case 3:
                    for(nt in selectedNotes){
                        song.notes[Math.floor(nt[0] / 16)].sectionNotes.remove(nt);
                        nt[0]++;
                        song.notes[Math.floor(nt[0] / 16)].sectionNotes.push(nt);
                    }
                // other stuff
                case 4:
                    var dupeNotes:Array<Array<Dynamic>> = [];
                    for(nt in selectedNotes){
                        var dupe = [nt[0], nt[1], nt[2], nt[3]];
                        dupeNotes.push(dupe);
                        song.notes[Math.floor(nt[0] / 16)].sectionNotes.push(dupe);
                    }
                    selectedNotes = dupeNotes;
                case 5:
                    for(nt in selectedNotes)
                        nt[1] = (Note.keyCount - 1) - nt[1];
                
                case 6:
                    selectedNotes = [];
                    for(nt in song.notes[curSec].sectionNotes)
                        selectedNotes.push(nt);
            }
            if(T >= 0)
                reloadNotes();

            return;
        }

        var T:Int = key.deepCheck([ 
            Binds.UI_BACK, 
            [KeyCode.ESCAPE, KeyCode.RETURN], 
            [KeyCode.SPACE],
            Binds.UI_L, 
            Binds.UI_R, 
            [KeyCode.B],
            [KeyCode.N], 
            [KeyCode.Q],
            [KeyCode.E],
            [KeyCode.X],
            [KeyCode.Z],
            [KeyCode.LEFT_CTRL],
            // Numbers 1 - 4
            [KeyCode.NUMBER_1], 
            [KeyCode.NUMBER_2], 
            [KeyCode.NUMBER_3], 
            [KeyCode.NUMBER_4]
        ]);

        switch(T){
            case 0, 1:
                // # Safety Checks

                if(song.song == '' || !lime.utils.Assets.exists(Paths.playableSong(song.song))){
                    postWarning('Warning: The song name either is empty or asset doesn\'t exist. ${song.song} / ${Paths.playableSong(song.song)}', 0xFFFF00);
                    return;
                }
                if(song.playLength > song.characters.length){
                    postWarning('Warning: More playing characters, than total characters in song. ${song.playLength} > ${song.characters.length}', 0xFFFF00);
                    return;
                }
                if(song.characters.length <= 0 || song.activePlayer > song.playLength){ // This would probably cause the game to crash.
                    postWarning('Error: Attempting to play as a character that doesn\'t exist. ${song.activePlayer} > ${song.characters.length}', 0xFF0000);
                    return;
                }

                ///////////////////////////
                FlxG.mouse.visible = false;
                MusicBeatState.changeState(new PlayState());

                FlxG.stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveEvent);
                FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDownEvent);
                FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP  , mouseUpEvent);

                overlappingElement = currentElement = null;

                PlayState.SONG = song;
            case 2:
                if(FlxG.sound.music.playing)
                    pauseSong();
                else {
                    FlxG.sound.music.play();

                    vocals.play();
                    vocals.time = FlxG.sound.music.time;

                    Song.Position = FlxG.sound.music.time - Settings.audio_offset;
                }
                return;
            case 3, 4:
                pauseSong();
                changeSec(curSec + (((T - 3) * 2) - 1));

                var offTime = curSec * Song.Crochet * 4;
                    offTime += Settings.audio_offset;

                // this is to make sure there are no trashy rounding errors.
                while(Math.floor((offTime + Settings.audio_offset) / (Song.Crochet * 4)) < curSec)
                    offTime += 0.011;

                Song.Position = vocals.time = FlxG.sound.music.time = offTime;
                Song.Position -= Settings.audio_offset;

                expandCheck();
                reloadNotes();
                return;
            case 5, 6:
                curNoteType += ((T - 5) * 2) - 1;
                curNoteType = CoolUtil.intBoundTo(curNoteType, 0, Note.possibleTypes.length - 1);

                for(nt in selectedNotes)
                    nt[4] = curNoteType;

                reloadNotes();
                return;
            case 7, 8:
                for(nt in selectedNotes)
                    nt[2] = CoolUtil.intBoundTo(nt[2] + ((T - 7) * 2 - 1), 0, 1000);
    
                reloadNotes();
                return;
            case 9, 10:
                curZoom += ((T - 9) * 2) - 1;
                curZoom = CoolUtil.intBoundTo(curZoom, 0, 8);

                makeGrid();
                reloadNotes();

                return;
            case 11:
                holdingControl = true;

            case 12, 13, 14, 15:
                [createSongUI, createCharUI, createSecUI, createInfoUI][T - 12]();
        }
    }
    override public function keyRel(KC:KeyCode, mod:KeyModifier){
        if(!mod.shiftKey)
            holdingControl = false;

        if(!mod.ctrlKey)
            holdingShift = false;
    }

    // # Note rendering code.

    public inline function reloadNotes(){
        var nCount:Int = 0;

        notes.clear();
        for(newnote in song.notes[curSec].sectionNotes){
            ++nCount;

            var daNote = new Note(newnote[0], newnote[1], newnote[4]);
            daNote.setGraphicSize(gridSize, gridSize);
            daNote.updateHitbox();
            daNote.x  = gridSize * daNote.noteData;
            daNote.x += gridSize * Note.keyCount * newnote[3];
            daNote.y  = (daNote.strumTime - (curSec * 16)) * zooms[curZoom] * gridSize;
            daNote.player = newnote[3];

            if(selectedNotes.contains(newnote)) 
                daNote.color = CoolUtil.cfArray(uiColours[3]);
            
            notes.add(daNote);

            for(i in 1...Math.floor((newnote[2] * zooms[curZoom]) + 1)){
                ++nCount;

                var susNote = new Note(newnote[0] + (i / zooms[curZoom]), newnote[1], newnote[4], true, i == Math.floor(newnote[2]*zooms[curZoom]));
                if(Settings.downscroll)
                    susNote.flipY = false;

                susNote.setGraphicSize(Std.int(gridSize / 2.5), gridSize);
                susNote.updateHitbox();
                susNote.x = daNote.x;
                susNote.y = (susNote.strumTime - (curSec * 16)) * zooms[curZoom] * gridSize;

                susNote.x += (gridSize / 2) - (susNote.width / 2);

                notes.add(susNote);
            }
        }

        trace('NOTES: $nCount');
    }

    // # Note functions

    public function delNote(nn:Array<Dynamic>):Bool {
        for(findNote in song.notes[curSec].sectionNotes)
            if(Math.abs(findNote[0] - nn[0]) < 1 / zooms[curZoom]
            && findNote[3] == nn[3] && findNote[1] == nn[1]){
                song.notes[curSec].sectionNotes.remove(findNote);
                reloadNotes();

                return true;
            }
        return false;
    }
    public function addNote(x:Int, y:Int){
        var newnote:Array<Dynamic> = [
            (Math.floor(y / gridSize) / zooms[curZoom]) + (curSec * 16),
            Math.floor(x / gridSize) % Note.keyCount,
            0,
            Math.floor(x / (gridSize * Note.keyCount)),
            curNoteType
        ];

        if(FlxG.mouse.x > camGR.x + camGR.width || delNote(newnote)) return;

        song.notes[curSec].sectionNotes.push(newnote);
        selectedNotes = [newnote];

        reloadNotes();
    }

    // # Mouse Events.

    var mouseHookX:Int = -1;
    var mouseHookY:Int = -1;

    public function mouseMoveEvent(ev:MouseEvent){
        noteHighlight.x = CoolUtil.boundTo(Math.floor((FlxG.mouse.x - camGR.x) / gridSize), 0, (song.playLength * Note.keyCount) - 1) * gridSize;
        noteHighlight.y = CoolUtil.boundTo(Math.floor((FlxG.mouse.y - camGR.y) / gridSize), 0, Math.floor(16 * zooms[curZoom]) - 1) * gridSize;

        // # Ui stuff

        if(FlxG.mouse.x >= uiBG.x){
            var foundMember:Bool = false;

            for(i in 0...uiElements.length){
                var member = uiElements.members[(uiElements.length - 1) - i];
                if(member == null) 
                    continue;

                if (FlxG.mouse.x < member.x || FlxG.mouse.y < member.y ||
                    FlxG.mouse.x >= member.x + member.width  ||
                    FlxG.mouse.y >= member.y + member.height || foundMember){
                    member.color = 0xFFFFFFFF;
                    continue;
                }

                foundMember = true;

                if (overlappingElement == member) 
                    continue;

                overlappingElement = member;
                member.color = 0xFFE5E5E5;
                member.mouseOverlaps();
            }
            if(!foundMember)
                overlappingElement = null;

            return;
        }
        
        overlappingElement = null;

        // # Selecting

        if(!holdingControl || mouseHookX == -1) return;

        var fakeX = FlxG.mouse.x - camGR.x;
        var fakeY = FlxG.mouse.y - camGR.y;
        if(fakeX < mouseHookX) blueSelectBox.x = fakeX;
        if(fakeY < mouseHookY) blueSelectBox.y = fakeY;

        blueSelectBox.scale.x = fakeX - mouseHookX;
        blueSelectBox.scale.y = fakeY - mouseHookY;
        blueSelectBox.updateHitbox();

        if(!holdingShift)
            selectedNotes = [];

        var relativeNote:Note = null;
        for(ppNote in song.notes[curSec].sectionNotes){
            notes.forEachAlive(function(daNote:Note){
                if (ppNote[0] != daNote.strumTime || daNote.isSustainNote ||
                    ppNote[1] != daNote.noteData  || ppNote[3] != daNote.player)
                    return;
                
                relativeNote = daNote;
            });
            relativeNote.color = 0xFFFFFFFF;

            if(selectedNotes.contains(ppNote)) {
                relativeNote.color = CoolUtil.cfArray(uiColours[3]);
                continue;
            }
            if (relativeNote.x < blueSelectBox.x || relativeNote.x + gridSize >= blueSelectBox.x + blueSelectBox.width ||
                relativeNote.y < blueSelectBox.y || relativeNote.y + gridSize >= blueSelectBox.y + blueSelectBox.height)
                continue;

            selectedNotes.push(ppNote);
            relativeNote.color = CoolUtil.cfArray(uiColours[3]);
        }
    }
    public function mouseDownEvent(ev:MouseEvent){
        // # UI Mouse Events

        if (overlappingElement != currentElement && currentElement != null)
            currentElement.forceExit();

        if (overlappingElement != null){
            overlappingElement.mouseDown();
            return;
        }

        ////////////////////////////////////

        if(!holdingControl){
            addNote(Math.round(noteHighlight.x), Math.round(noteHighlight.y));
            return;
        }

        blueSelectBox.x = mouseHookX = Math.floor(FlxG.mouse.x - camGR.x);
        blueSelectBox.y = mouseHookY = Math.floor(FlxG.mouse.y - camGR.y);
    }
    public function mouseUpEvent(ev:MouseEvent){
        // # UI 

        if (currentElement != null){
            currentElement.mouseUp();
            return;
        }

        ///////////

        blueSelectBox.x = blueSelectBox.y = 
        mouseHookX = mouseHookY = -1;
        blueSelectBox.scale.set(0.1,0.1);
    }
    
    /////////////////////////////////////////////////

    override public function update(elapsed:Float){
        var secRef:Float = CoolUtil.boundTo(Song.Position / (Song.Crochet * 4), 0, FlxG.sound.music.length);

        // # Right click

        if(FlxG.mouse.justPressedRight){
            for(rem in selectedNotes)
                PlayState.SONG.notes[Math.floor(rem[0] / 16)].sectionNotes.remove(rem);

            selectedNotes = [];
            reloadNotes();
            return;
        }
        // # Scrolling

        var wheel = FlxG.mouse.wheel * -50;
        if(wheel != 0 && currentElement == null){
            pauseSong();

            vocals.time = 
            FlxG.sound.music.time = 
            CoolUtil.boundTo(FlxG.sound.music.time + wheel, 0, FlxG.sound.music.length);
        }

        // # Changing Sections

        if(secRef >= curSec + 1 || secRef < curSec)
            changeSec(Math.floor(secRef));

        var calcY:Float = secRef - curSec;
            camGR.y = calcY * zooms[curZoom] * 2 * -250;
            camGR.y += 125;
        musicLine.y = calcY * gridLayer.members[0].height;

        super.update(elapsed);
    }

    private inline function expandCheck()
        if(curSec >= song.notes.length){
            song.notes.push({
                sectionNotes: [],
                cameraFacing: 0
            });
        }

    // # Text at top

    private var textTween:FlxTween;
    public inline function postWarning(text:String, colour:Int){
        if(textTween != null)
            textTween.cancel();

        warningTxt.x = camGR.x + camGR.width + 10;
        warningTxt.alpha = 1;
        warningTxt.color = colour;
        warningTxt.text  = text;

        textTween = FlxTween.tween(warningTxt, {alpha: 0}, 1.5, {startDelay: 1});
    }

    // # UI Tabs.

    private var currentTab:Int = 0;
    private var tabButtons:Array<ChartUI_Button> = [];
    private inline function genText(ref:ChartUI_Generic, txt:String):ChartUI_Text
    {
        var tmpText:ChartUI_Text = new ChartUI_Text(ref.x + ref.width + 5, ref.y, txt);
            tmpText.y += (ref.height - tmpText.height) / 2;
            tmpText.y -= uiElements.y;
            tmpText.x -= uiElements.x;
        uiElements.add(tmpText);

        return tmpText;
    }
    
    private inline function uiStart(?tab:Int = 0){
        currentTab = tab;
        if(currentElement != tabButtons[tab])
            overlappingElement = currentElement = null;

        for(i in 0...tabButtons.length)
            uiElements.remove(tabButtons[i]);

        uiElements.clear();
        for(i in 0...tabButtons.length)
            uiElements.add(tabButtons[i]);
    }

    // Info UI stuff
    private static var infoText:String = '
    About / Info / How to use:\n
    Left Click - Add note
    Left Click on note - Delete note
    Right Click - Delete selected notes
    Ctrl + Left Click + Drag - Select multiple notes
    Q / E - Decrease / add length of selected notes
    Z / X - Zoom in or zoom out grid
    B / N - Change note types
    SPACE - Pause / Play song\n
    Ctrl \"Power Moves\" (on selected notes):\n
    Ctrl + J / L - Moves notes left / right on the grid
    Ctrl + I / K - Moves notes up / down on the grid
    Ctrl + C - Makes of copy of selected notes
    Ctrl + V mirrors selected notes
    ';
    public function createInfoUI():Void
    {
        uiStart(3);

        var aboutText:ChartUI_Text = new ChartUI_Text(-20, -30, infoText);
        uiElements.add(aboutText);
        mouseMoveEvent(null);
    }

    public function createSongUI():Void
    {
        uiStart(0);

        // Top stuff

        var nameBox:ChartUI_InputBox = new ChartUI_InputBox(0, 0, 190, 30, song.song, function(ch:String){
            song.song = ch;
            PlayState.songName = ch.toLowerCase();
        });
        var bpmBox:ChartUI_InputBox = new ChartUI_InputBox(200, 0, 90, 30, Std.string(song.bpm), function(ch:String){
            song.bpm = Std.parseFloat(ch);
            Song.musicSet(song.bpm);
        });
        var delayBox:ChartUI_InputBox = new ChartUI_InputBox(0, 40, 70, 30, Std.string(song.beginTime), function(ch:String){
            song.beginTime = Std.parseFloat(ch);
        });

        var stageDrop:ChartUI_DropDown = new ChartUI_DropDown(0, 80, 160, 30, Paths.lLines('stageList'), song.stage, function(index:Int, ch:String){
            song.stage = ch;
        }, uiElements);
        var speedBox:ChartUI_InputBox = new ChartUI_InputBox(200, 80, 90, 30, Std.string(song.speed), function(ch:String){
            song.speed = Std.parseFloat(ch);
        });

        // Bottom stuff

        var voicesCheck:ChartUI_CheckBox = new ChartUI_CheckBox(0, 550, song.needsVoices, function(ch:Bool){
            song.needsVoices = ch;
            pauseSong();

            vocals = new FlxSound();
            vocals.time = FlxG.sound.music.time;
            FlxG.sound.list.add(vocals);

            if(!ch) return;

            vocals.loadEmbedded(Paths.playableSong(song.song, true));
        });
        var reloadButton:ChartUI_Button = new ChartUI_Button(260, 430, 130, 30, function(){
            pauseSong();

            FlxG.sound.playMusic(Paths.playableSong(song.song, false));

            FlxG.sound.music.pause();
            FlxG.sound.music.time = 0;
            if(!song.needsVoices) return;

            vocals = new FlxSound();
            vocals.time = 0;
            vocals.loadEmbedded(Paths.playableSong(song.song, true));

            FlxG.sound.list.add(vocals);
        }, 'Update Song');
        var selectButton:ChartUI_Button = new ChartUI_Button(260, 470, 130, 30, function(){
            selectedNotes = [];

            for(sec in song.notes)
                for(nt in sec.sectionNotes)
                    selectedNotes.push(nt);

            reloadNotes();
        }, 'Select All');
        var resetButton:ChartUI_Button = new ChartUI_Button(260, 510, 130, 30, function(){
            pauseSong();

            FlxG.sound.music.time = vocals.time = 0;

            song.notes = [];
            song.bpm = 120;
            song.needsVoices = true;
            song.speed = 1;

            Song.musicSet(song.bpm);
            changeSec(0);
            reloadNotes();
        }, 'Clear Song');
        var saveSong:ChartUI_Button = new ChartUI_Button(260, 550, 130, 30, function(){
            var path = 'assets/songs-data/${PlayState.songName}/edited.json';
            var saveString:String = 'You cannot save charts in web build.';

            #if desktop
            saveString = 'Saved song to "$path"';

            var stringedSong:String = Json.stringify({"song": song}, '\t');
            File.saveContent(path,stringedSong);
            #end

            postWarning(saveString, 0xFFFFFFFF);
        }, 'Save Song');

        uiElements.add(nameBox);
        uiElements.add(bpmBox);
        uiElements.add(delayBox);
        uiElements.add(stageDrop);
        uiElements.add(speedBox);

        uiElements.add(voicesCheck);
        uiElements.add(reloadButton);
        uiElements.add(selectButton);
        uiElements.add(resetButton);
        uiElements.add(saveSong);

        genText(bpmBox,    'BPM');
        genText(delayBox,  'Seconds Before Song Starts');
        genText(speedBox,  'Scroll Speed');
        genText(voicesCheck, 'Use Voices');
        mouseMoveEvent(null);
    }

    // Character UI stuff
    private var characterNames:Array<String>;
    private inline function charUIGenPlayerDrop(ind:Int)
    {
        var tmpDrop:ChartUI_DropDown = new ChartUI_DropDown(0, ind * 35, 160, 30, characterNames, song.characters[ind], function(index:Int, item:String){
            song.characters[ind] = item; makeGrid(); }, uiElements);

        uiElements.add(tmpDrop);
        genText(tmpDrop, 'Player ${ind + 1}');
    }
    public function createCharUI(){
        uiStart(1);

        // Get a list of characters from the characterLoader JSON file
        characterNames = [];
        var charData:Array<gameplay.Character.CharacterData> = Json.parse(Paths.lText('characterLoader.json')).characters;

        for(char in charData)
            characterNames.push(char.name.trim());
        ///////////////////////////////////////////

        var addButton:ChartUI_Button = new ChartUI_Button(360, 0, 30, 30, function(){
            if(song.characters.length >= 13) 
                return;

            song.characters.push('bf');
            charUIGenPlayerDrop(song.characters.length - 1);
        }, '+');
        var remButton:ChartUI_Button = new ChartUI_Button(320, 0, 30, 30, function(){
            if(song.characters.length <= 1) 
                return;

            song.characters.splice(song.characters.length - 1, 1);
            var nLen = uiElements.length - 1;

            uiElements.remove(uiElements.members[nLen],     true);
            uiElements.remove(uiElements.members[nLen - 1], true);

            if(song.characters.length != 1) 
                return;

            song.playLength = 1;
            makeGrid();
        }, '-');
        var playLenBox:ChartUI_InputBox = new ChartUI_InputBox(0, 550, 90, 30, Std.string(song.playLength), function(ch:String){
            var val = CoolUtil.intBoundTo(Std.parseInt(ch), 1, Math.max(song.characters.length, 1));

            song.playLength = val;
            
            gridSizeCalc();
            changeSec(curSec);
            makeGrid();
        });
        var playerBox:ChartUI_InputBox = new ChartUI_InputBox(0, 510, 90, 30, Std.string(song.activePlayer), function(ch:String){
            song.activePlayer = CoolUtil.intBoundTo(Std.parseInt(ch), 0, song.playLength - 1);
        });
        var backwardsBox:ChartUI_CheckBox = new ChartUI_CheckBox(0, 470, 30, 30, song.renderBackwards, function(ch:Bool){
            song.renderBackwards = !song.renderBackwards;
        });

        uiElements.add(addButton);
        uiElements.add(remButton);
        uiElements.add(playLenBox);
        uiElements.add(playerBox);
        uiElements.add(backwardsBox);

        genText(playLenBox,   'Character Chart List');
        genText(playerBox,    'Main Player');
        genText(backwardsBox, 'Render characters backwards');
        for(i in 0...CoolUtil.intBoundTo(song.characters.length, 1, 13))
            charUIGenPlayerDrop(i);

        mouseMoveEvent(null);
    }

    // Section UI stuff
    private var copyLastInt:Int = 2;
    public function createSecUI():Void
    {
        uiStart(2);

        var cameraBox:ChartUI_InputBox = new ChartUI_InputBox(0, 0, 120, 30, Std.string(song.notes[curSec].cameraFacing), function(ch:String){
            song.notes[curSec].cameraFacing = CoolUtil.intBoundTo(Std.parseInt(ch), 0, song.characters.length - 1);
        });
        var clBox:ChartUI_InputBox = new ChartUI_InputBox(0, 40, 120, 30, Std.string(copyLastInt), function(ch:String){
            copyLastInt = Std.parseInt(ch);
        });

        //////////////////////////////////////


        var snButton:ChartUI_Button = new ChartUI_Button(0, 550, 120, 30, function(){
            selectedNotes = [];
            for(nt in song.notes[curSec].sectionNotes)
                selectedNotes.push(nt);

            reloadNotes();
        }, 'Select');
        var swapButton:ChartUI_Button = new ChartUI_Button(0, 510, 120, 30, function(){
            for(nt in song.notes[curSec].sectionNotes)
                nt[3] = (nt[3] + 1) % song.playLength;

            selectedNotes = [];
            reloadNotes();
        }, 'Swap');
        var copyButton:ChartUI_Button = new ChartUI_Button(0, 470, 120, 30, function(){
            if(curSec - copyLastInt < 0) return;

            for(nt in song.notes[curSec-copyLastInt].sectionNotes)
                song.notes[curSec].sectionNotes.push([nt[0]+(copyLastInt*16), nt[1], nt[2], nt[3]]);
            
            reloadNotes();
        }, 'Copy Last');
        var clearButton:ChartUI_Button = new ChartUI_Button(0, 430, 120, 30, function(){
            song.notes[curSec].sectionNotes = [];
            selectedNotes = [];

            reloadNotes();
        }, 'Clear');

        var secText:ChartUI_Text = new ChartUI_Text(0, 85, 'Current Section: $curSec');

        uiElements.add(snButton);
        uiElements.add(swapButton);
        uiElements.add(copyButton);
        uiElements.add(clearButton);
        uiElements.add(cameraBox);
        uiElements.add(clBox);
        uiElements.add(secText);

        genText(cameraBox, 'Camera Facing');
        genText(clBox,     'Copy Last Sections Back');
        mouseMoveEvent(null);
    }
}