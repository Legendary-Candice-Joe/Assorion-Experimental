package gameplay;

import flixel.FlxBasic;
import flixel.group.FlxGroup;

class NoteGroup<T:FlxBasic> extends FlxTypedGroup<T> {
    public var drawableObjects:Array<T>;
    public var activeObjects:Array<T>; // All notes are inactive, so this is useless lol

    override public function add(Object:T):T
    {
        if (Object == null)
			return null;

		if (members.indexOf(Object) >= 0)
			return Object;

		var index:Int = getFirstNull();
		if (index != -1)
		{
			members[index] = Object;

			if (index >= length)
				length = index + 1;

			if (_memberAdded != null)
				_memberAdded.dispatch(Object);

			return Object;
		}

		if (maxSize > 0 && length >= maxSize)
			return Object;

		members.push(Object);
		length++;

		if (_memberAdded != null)
			_memberAdded.dispatch(Object);

        if(Object.visible)
            drawableObjects.push(Object);

        if(Object.active)
            activeObjects.push(Object);

        return Object;
    }

    override public function update(elapsed:Float):Void
    {
        /*var i:Int = 0;
        var basic:FlxBasic = null;

        while (i < length)
        {
            basic = members[i++];

            if (basic != null && basic.exists && basic.active)
            {
                basic.update(elapsed);
            }
        }*/

        for(i in 0...length){
            var basic:FlxBasic = activeObjects[i];

            if(basic != null && basic.exists)
                basic.update(elapsed);
        }
    }

    override public function draw():Void
    {
        /*var i:Int = 0;
        var basic:FlxBasic = null;

        while (i < length)
        {
            basic = members[i++];

            if (basic != null && basic.exists && basic.visible)
            {
                basic.draw();
            }
        }*/

        for(i in 0...length){
            var basic:FlxBasic = drawableObjects[i];

            if(basic != null && basic.exists)
                basic.draw();
        }

        //FlxCamera._defaultCameras = oldDefaultCameras;
    }
}