package backend;

import haxe.ds.Vector;
import lime.utils.Assets;
import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Array<Dynamic>>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;
	var format:String;

	@:optional var isOldVersion:Bool;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;
	
	@:optional var disableNoteRGB:Bool;
	@:optional var screwYou:String;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;

	// internal flag to track lazy conversion
	@:optional var __converted:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Array<Dynamic>>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psych_v1';

	// ------------------------
	// Lazy loaded sections
	// ------------------------
	private var _rawSections:Array<SwagSection> = [];

	// ------------------------
	// Convert old charts to psych_v1 format
	// ------------------------
	public static function convert(songJson:Dynamic)
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			for(sec in songJson.notes)
			{
				var i = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				while(i < notes.length)
				{
					var note = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
					}
					else i++;
				}
			}
		}
	}

	// ------------------------
	// Load chart JSON lazily
	// ------------------------
	public static function loadFromJson(jsonInput:String, ?folder:String, ?forPlay:Bool = true):SwagSong
	{
		if(folder == null) folder = jsonInput;

		// read raw chart data
		var path = Paths.json(Paths.formatToSongPath(folder) + "/" + Paths.formatToSongPath(jsonInput));
		var raw:String = null;

		#if desktop
		if(NativeFileSystem.exists(path))
			raw = NativeFileSystem.getContent(path);
		#else
		raw = Assets.getText(path);
		#end

		if(raw == null) return null;

		var song:SwagSong = cast SongJson.parse(raw);

		// store raw sections but do not convert all notes
		if(song.notes != null) for(sec in song.notes) sec.__converted = false;

		// lazy conversion only when playing
		if(forPlay)
			return song;

		return song;
	}

	// ------------------------
	// Get a section safely, converting it on demand
	// ------------------------
	public static function getSection(song:SwagSong, index:Int):SwagSection
	{
		if(index < 0 || index >= song.notes.length) return null;

		var sec = song.notes[index];

		if(!sec.__converted)
		{
			for(note in sec.sectionNotes)
			{
				var gottaHit = (note[1] < 4) ? sec.mustHitSection : !sec.mustHitSection;
				note[1] = (note[1] % 4) + (gottaHit ? 0 : 4);

				if(note[3] != null && !Std.isOfType(note[3], String))
					note[3] = Note.DEFAULT_NOTE_TYPES[note[3]];
			}
			sec.__converted = true;
		}

		return sec;
	}
}
