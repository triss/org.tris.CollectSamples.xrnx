--[[============================================================================
Collect Samples - main.lua
============================================================================]]--

_AUTO_RELOAD_DEBUG = true

--------------------------------------------------------------------------------
--  Preferences
--------------------------------------------------------------------------------

local SLICED_FILE_MODE = {ask=1, copy_src=2, skip=3}

local options = renoise.Document.create("ScriptingToolPreferences") {
  start_mapping_from = 36,
  sliced_file_mode = SLICED_FILE_MODE.copy_src
}

renoise.tool().preferences = options

--------------------------------------------------------------------------------
-- Helper functions
--------------------------------------------------------------------------------

-- true when n is between range[1] and range[2]
local function between(n, range)
  return n >= range[1] and n <= range[2]
end

--------------------------------------------------------------------------------
-- Main functions
--------------------------------------------------------------------------------

-- we keep track of sliced instruments as we see them as we only want to copy
-- the source sample once.
local sliced_instruments = {}

-- returns table of the SampleMappings which trigger for the specified note.
-- ignore's velocity (and NOTE_OFF layer) for now
local function sample_mappings_for_note(i, note)
  local instrument = renoise.song():instrument(i)
  local mappings = table.create()

  for _,sm in pairs(instrument.sample_mappings[1]) do
    if between(note, sm.note_range) then
      if not sm.read_only then
        mappings:insert(sm)
      elseif options.sliced_file_mode.value == SLICED_FILE_MODE.copy_src then
        if not sliced_instruments[i] then
          mappings:insert(instrument.sample_mappings[1][1])
          sliced_instruments[i] = true
        end
      end
    end
  end
  
  return mappings
end

-- returns table of all of the samples used in a range of note_columns specified
-- by the note_column_it
local function used_sample_mappings(note_column_it)
  sliced_instruments = {}
  local mappings = {}

  for pos, column in note_column_it do
    local note = column.note_value
    local instrument = column.instrument_value + 1
    
    if note < 120 and instrument < 255 then
      if not mappings[instrument] then 
        mappings[instrument] = table.create()
      end
      if not mappings[instrument][note] then
        mappings[instrument][note] = sample_mappings_for_note(instrument, note)
      end
    end
  end

  return mappings
end

-- only used when we have to deal with sliced samples
-- assume's sliced sample is the first in the instrument? (it always is?)
local function save_load_source_sample(src_sample, dest_sample) 
  local tmp_name = os.tmpname('.wav')
  src_sample.sample_buffer:save_as(tmp_name, 'wav')
  dest_sample.sample_buffer:load_from(tmp_name)
  dest_sample.name = src_sample.name
  dest_sample.panning = src_sample.panning
  dest_sample.volume = src_sample.volume
  dest_sample.transpose = src_sample.transpose
  dest_sample.fine_tune = src_sample.fine_tune
  dest_sample.beat_sync_enabled = src_sample.beat_sync_enabled
  dest_sample.beat_sync_lines = src_sample.beat_sync_lines
  dest_sample.beat_sync_mode = src_sample.beat_sync_mode
  dest_sample.interpolation_mode = src_sample.interpolation_mode
  dest_sample.oversample_enabled = src_sample.oversample_enabled
  dest_sample.new_note_action = src_sample.new_note_action
  dest_sample.oneshot = src_sample.oneshot
  dest_sample.autoseek = src_sample.autoseek
  dest_sample.autofade = src_sample.autofade
  dest_sample.loop_mode = src_sample.loop_mode
  dest_sample.loop_release = src_sample.loop_release
  dest_sample.loop_start = src_sample.loop_start
  dest_sample.loop_end = src_sample.loop_end
end

-- copies every sample referenced in sample_mappings and adds them to the
-- destination instrument.
-- Every sample gets it's own note.
-- If a sample was layered with another in the source instrument it is also 
-- layered with it in the destination.
local function copy_sample_mappings_to_instrument(sample_mappings, dest)
  local rs = renoise.song()
  local note_to_map = options.start_mapping_from.value

  for _,instrument_mapping in pairs(sample_mappings) do 
    for _,note_mapping in pairs(instrument_mapping) do
      for _,layer_mapping in pairs(note_mapping) do
        local s = dest:insert_sample_at(#dest.samples+1)
        if not layer_mapping.read_only then
          s:copy_from(layer_mapping.sample)
        else
          save_load_source_sample(layer_mapping.sample, s)
        end
        s.sample_mapping.base_note = note_to_map
        s.sample_mapping.note_range = {note_to_map, note_to_map}
      end

      note_to_map = note_to_map + 1
    end
  end
end

-- copies every used sample in the song to a newly created instrument
local function copy_song_samples_to_new_instrument()
  local rs = renoise.song()
  local it = rs.pattern_iterator:note_columns_in_song()
  local sms = used_sample_mappings(it)
  local dest = rs:insert_instrument_at(1)
  dest.name = rs.name .. " song source samples"
  copy_sample_mappings_to_instrument(sms, dest)
end

-- copies every used sample in the selected pattern to a newly created instrument
local function copy_pattern_samples_to_new_instrument()
  local rs = renoise.song()
  local it = rs.pattern_iterator:note_columns_in_pattern(rs.selected_pattern_index)
  local sms = used_sample_mappings(it)
  local dest = rs:insert_instrument_at(1)
  dest.name = rs.selected_pattern.name .. " pattern source samples"
  copy_sample_mappings_to_instrument(sms, dest)
end

-- copies every used sample in the selected track to a newly created instrument
local function copy_track_samples_to_new_instrument()
  local rs = renoise.song()
  local it = rs.pattern_iterator:note_columns_in_track(rs.selected_track_index)
  local sms = used_sample_mappings(it)
  local dest = rs:insert_instrument_at(1)
  dest.name = rs.selected_track.name .. " track source samples"
  copy_sample_mappings_to_instrument(sms, dest)
end

--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy all used Samples:from Song to a new Instrument",
  invoke = copy_song_samples_to_new_instrument
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy all used Samples:from Pattern to a new Instrument",
  invoke = copy_pattern_samples_to_new_instrument
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy all used Samples:from Track to a new Instrument",
  invoke = copy_track_samples_to_new_instrument
}

--------------------------------------------------------------------------------
-- Keyboard shortcuts
--------------------------------------------------------------------------------

renoise.tool():add_keybinding {
  name = "Global:Copy all used Samples:from Song to a new Instrument",
  invoke = copy_song_samples_to_new_instrument
}

renoise.tool():add_keybinding {
  name = "Global:Copy all used Samples:from Pattern to a new Instrument",
  invoke = copy_pattern_samples_to_new_instrument
}

renoise.tool():add_keybinding {
  name = "Global:Copy all used Samples:from Track to a new Instrument",
  invoke = copy_track_samples_to_new_instrument
}
