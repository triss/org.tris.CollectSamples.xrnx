--[[============================================================================
Collect Samples - main.lua
============================================================================]]--

_AUTO_RELOAD_DEBUG = true

--------------------------------------------------------------------------------
--  Preferences
--------------------------------------------------------------------------------

local options = renoise.Document.create("ScriptingToolPreferences") {
  start_mapping_from = 36
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

-- returns table of the SampleMappings which trigger for the specified note.
-- ignore's velocity (and NOTE_OFF layer) for now
local function sample_mappings_for_note(i, note)
  local instrument = renoise.song():instrument(i)
  local mappings = table.create()
  for _,sm in pairs(instrument.sample_mappings[1]) do
    if between(note, sm.note_range) then
      mappings:insert(sm)
    end
  end
  return mappings
end

-- returns table of all of the samples used in a range of note_columns specified
-- by the note_column_it
local function used_sample_mappings(note_column_it)
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

-- copies every sample referenced in sample_mappings and adds them to a new 
-- instrument.
-- Every sample gets it's own note.
-- If a sample was layered with another in the source instrument it is also 
-- layered with it in the destination.
local function copy_sample_mappings_to_new_instrument(sample_mappings)
  local rs = renoise.song()
  local dest = rs:insert_instrument_at(#rs.instruments+1)
  local note_to_map = options.start_mapping_from.value

  for _,instrument_mapping in pairs(sample_mappings) do 
    for _,note_mapping in pairs(instrument_mapping) do
      for _,layer_mapping in pairs(note_mapping) do
        local s = dest:insert_sample_at(#dest.samples+1)
        s:copy_from(layer_mapping.sample)
        s.sample_mapping.base_note = note_to_map
        s.sample_mapping.note_range = {note_to_map, note_to_map}
      end

      note_to_map = note_to_map + 1
    end
  end
end

--------------------------------------------------------------------------------
-- Menu entries
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy all used Samples to a new Instrument",
  invoke = function()
    copy_sample_mappings_to_new_instrument(used_sample_mappings(renoise.song().pattern_iterator:note_columns_in_song()))
  end
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:Copy all used Samples from Pattern to a new Instrument",
  invoke = function()
    copy_sample_mappings_to_new_instrument(used_sample_mappings(renoise.song().pattern_iterator:note_columns_in_pattern(renoise.song().selected_pattern_index)))
  end
}
