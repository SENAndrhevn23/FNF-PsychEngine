package backend;

import haxe.Json;
import lime.utils.Assets;
import objects.Note;
import sys.io.File;
import sys.FileSystem;

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
}

class Song
{
	// Static fields to fix missing references
	public static var chartPath:String;
	public static var loadedSongName:String;

	// Song properties
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

	// Convert old charts to psych_v1 format
	public static function convert(songJson:Dynamic):Void
	{
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			if(Reflect.hasField(songJson, 'player3')) Reflect.deleteField(songJson, 'player3');
		}

		if(songJson.events == null)
		{
			songJson.events = [];
			var notesArray:Array<SwagSection> = cast songJson.notes;
			for(sec in notesArray)
			{
				var notes:Array<Dynamic> = sec.sectionNotes;
				var i:Int = 0;
				while(i < notes.length)
				{
					var note:Array<Dynamic> = cast notes[i];
					if(note[1] < 0)
					{
						songJson.events.push(cast [note[0], [[note[2], note[3], note[4]]]] : Array<Dynamic>);
						notes.remove(note);
					}
					else i++;
				}
			}
		}

		var sectionsData:Array<SwagSection> = cast songJson.notes;
		if(sectionsData == null) return;

		for(section in sectionsData)
		{
			if(section.sectionBeats == null || Math.isNaN(section.sectionBeats))
				section.sectionBeats = 4;

			for(note in section.sectionNotes)
			{
				var n:Array<Dynamic> = cast note;
				var gottaHitNote:Bool = (n[1] < 4) ? section.mustHitSection : !section.mustHitSection;
				n[1] = (n[1] % 4) + (gottaHitNote ? 0 : 4);

				if(n[3] != null && !Std.isOfType(n[3], String))
					n[3] = Note.defaultNoteTypes[n[3]];
			}
		}
	}

	// Load chart from JSON
	public static function loadFromJson(jsonInput:String, ?forPlay:Bool = false, ?folder:String = null):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var song:SwagSong = getChart(jsonInput, folder);
		PlayState.SONG = song;
		loadedSongName = folder;
		chartPath = lastPath;

		StageData.loadDirectory(song);
		return song;
	}

	static var lastPath:String;

	// Get chart from file or assets
	public static function getChart(jsonInput:String, ?folder:String = null):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		lastPath = Paths.json('$formattedFolder/$formattedSong');

		var rawData:String = null;
		if(FileSystem.exists(lastPath))
			rawData = File.getContent(lastPath);
		else
			rawData = Assets.getText(lastPath);

		return rawData != null ? parseJSON(rawData) : null;
	}

	// Parse JSON into SwagSong
	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psych_v1'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);

		if(Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if(subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if(convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if(fmt == null) fmt = songJson.format = 'unknown';
			if(!fmt.startsWith('psych_v1'))
			{
				songJson.format = 'psych_v1_convert';
				convert(songJson);
			}
		}
		return songJson;
	}
}
