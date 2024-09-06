local mod = require "core/mods"
local nb = require "nb/lib/nb"
local switch = 1
local note_hist = {}

local function format_percent(val)
    return(val.."%")
end

-- note-based crossover between two layers
local function pitch_crossover(midi_note, crossover, width, overlap)
    local overlap = overlap * width * 2 / 100 - width -- scale % overlap to +/- width
    
    -- Calculate the difference from the crossover point
    local delta1 = midi_note - crossover - overlap
    local delta2 = midi_note - crossover + overlap

    -- Determine the scaling factors for both layers
    local factor1, factor2

    if delta1 <= -width then
        factor1 = 1 -- full if below transition
    elseif delta1 >= width then
        factor1 = 0 -- none if above transition
    else
        -- Calculate the factor for the transition range
        local normalized_delta = (delta1 + width) / (2 * width) -- Normalize between 0 and 1
        factor1 = math.cos(normalized_delta * math.pi / 2)^2 -- Sinusoidal transition
    end

    if delta2 <= -width then
        factor2 = 0 -- none if below transition
    elseif delta2 >= width then
        factor2 = 1 -- full if above transition
    else
        -- Calculate the factor for the transition range
        local normalized_delta = (delta2 + width) / (2 * width) -- Normalize between 0 and 1
        factor2 = math.sin(normalized_delta * math.pi / 2)^2 -- Sinusoidal transition
    end

    return factor1, factor2
end

local function note_name(note_num)
    local names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local octave = math.floor(note_num / 12) - 2
    local note_name = names[(note_num % 12) + 1]
    return note_num .. " " .. note_name .. octave
end

-- passed string arg will be looked up in param"s .options and set using index
local function set_param_string(param, str)
    params:set(param, tab.key(params:lookup_param(param).options, str))
end

local function add_player()
    local player = {}

    function player:add_params()
        local player_ids = {}

        for k, v in pairs(note_players) do
            local midi_ds = string.sub(k, 1, 7) == "midi_ds" -- hide router and dreamsequence's custom midi players
            if not (midi_ds or k == "router") then
                table.insert(player_ids, k)
            end
        end
        table.sort(player_ids, function(a, b)
            return string.lower(a) < string.lower(b)
        end)
        table.insert(player_ids, 1, "none")
        
        params:add_group("nb_router", "router", 13)

        nb:add_param("nb_router_voice_1_private", "nb_router_voice_1_private") -- hidden param used to handle nb backend stuff like nb_player_refcounts
        params:hide("nb_router_voice_1_private")
        -- params:set_save("nb_router_voice_1_private", false) -- use with post init to address text param bug

        nb:add_param("nb_router_voice_2_private", "nb_router_voice_2_private")
        params:hide("nb_router_voice_2_private")
        -- params:set_save("nb_router_voice_2_private", false) -- use with post init to address text param bug

        -- selector param exposed to user, with some options excluded
        params:add_option("nb_router_voice_1", "voice 1", player_ids, 1)
        params:set_action("nb_router_voice_1",
            function() 
                set_param_string("nb_router_voice_1_private", params:string("nb_router_voice_1"))
                -- params:lookup_param("nb_router_voice_1_private"):bang() -- gotta bang explicitly or nb_player_refcounts ends up with mix of string and num indexed entries??!!
            end
        )

        params:add_option("nb_router_voice_2", "voice 2", player_ids, 1)
        params:set_action("nb_router_voice_2",
            function() 
                set_param_string("nb_router_voice_2_private", params:string("nb_router_voice_2"))
                -- params:lookup_param("nb_router_voice_2_private"):bang()
            end
        )

        params:add_option("nb_router_mode", "mode", {"mult", "mix", "x-over", "rotate"}, 1)
        params:set_action("nb_router_mode", 
        function()
            local mode = params:string("nb_router_mode")

            params:hide("nb_router_mix")
            params:hide("nb_router_xover_note")
            params:hide("nb_router_xover_width")
            params:hide("nb_router_xover_overlap")
            params:hide("nb_router_xover_floor_1")
            params:hide("nb_router_xover_floor_2")

            if mode == "mix" then
                params:show("nb_router_mix")
            elseif mode == "x-over" then
                params:show("nb_router_xover_note")
                params:show("nb_router_xover_width")
                params:show("nb_router_xover_overlap")
                params:show("nb_router_xover_floor_1")
                params:show("nb_router_xover_floor_2")
            end
            _menu.rebuild_params()
        end
        )

        params:add_number("nb_router_mix", "mix", 0, 100, 50, function(param) return (100 - param:get()) .. "/" .. param:get() end)
        params:add_number("nb_router_xover_note", "x-over note", 0, 127, 60, function(param) return note_name(param:get()) end)
        params:add_number("nb_router_xover_width", "x-over width", 0, 100, 36)
        params:add_number("nb_router_xover_overlap", "x-over overlap", 0, 100, 50, function(param) return format_percent(param:get()) end)
        params:add_number("nb_router_xover_floor_1", "voice 1 floor", 0, 100, 0, function(param) return format_percent(param:get()) end)
        params:add_number("nb_router_xover_floor_2", "voice 2 floor", 0, 100, 0, function(param) return format_percent(param:get()) end)

        params:hide("nb_router")
    end
  
    function player:note_on(note, vel)
        local style = params:string("nb_router_mode")
        local player_1 = params:lookup_param("nb_router_voice_1_private"):get_player()
        local player_2 = params:lookup_param("nb_router_voice_2_private"):get_player()

        if style == "mult" then
            player_1:note_on(note, vel)
            player_2:note_on(note, vel)
        elseif style == "x-over" then
            local vel_1, vel_2 = pitch_crossover(note, params:get("nb_router_xover_note"), params:get("nb_router_xover_width"), params:get("nb_router_xover_overlap"))
            local floor_1 = params:get("nb_router_xover_floor_1") / 100
            local floor_2 = params:get("nb_router_xover_floor_2") / 100

            if floor_1 ~= 0 then
                vel_1 = vel * (vel_1 * (1 - floor_1) + floor_1)
            else
                vel_1 = vel * vel_1
            end

            if floor_2 ~= 0 then
                vel_2 = vel * (vel_2 * (1 - floor_2) + floor_2)
            else
                vel_2 = vel * vel_2
            end

            player_1:note_on(note, vel_1)
            player_2:note_on(note, vel_2)

        elseif style == "mix" then
            local normalized_mix = params:get("nb_router_mix") / 100
            local factor = math.sin(normalized_mix * math.pi / 2)^2

            player_1:note_on(note, vel * (1 - factor))
            player_2:note_on(note, vel * factor)
            
        elseif style == "rotate" then
            if switch == 1 then
                if note_hist[note] then
                    -- shouldn't happen!
                else
                    note_hist[note] = 1
                end
                player_1:note_on(note, vel)
                switch = 2
            else
                if note_hist[note] then
                    -- shouldn't happen!
                else
                    note_hist[note] = 2
                end
                player_2:note_on(note, vel)
                switch = 1
            end
        end
    end
  
    function player:note_off(note)
        local player_1 = params:lookup_param("nb_router_voice_1_private"):get_player()
        local player_2 = params:lookup_param("nb_router_voice_2_private"):get_player()

        if params:string("nb_router_mode") == "rotate" then
            local switch = note_hist[note]
            if switch == 1 then
                player_1:note_off(note)
                note_hist[note] = nil
            elseif switch == 2 then
                player_2:note_off(note)
                note_hist[note] = nil
            else -- shouldn't happen but just in case
                player_1:note_off(note)
                player_2:note_off(note)
            end
        else
            player_1:note_off(note)
            player_2:note_off(note)
        end
    end

    function player:active()
        params:lookup_param("nb_router_voice_1"):bang() -- to decrement nb_player_refcounts
        params:lookup_param("nb_router_voice_2"):bang()
        params:show("nb_router")
        _menu.rebuild_params()
    end

    function player:inactive()
        params:set("nb_router_voice_1_private", 1)
        params:set("nb_router_voice_2_private", 1)
        params:hide("nb_router")
        _menu.rebuild_params()
    end

    function player:stop_all()
        if params.lookup["nb_router_voice_1_private"] then
            local player_1 = params:lookup_param("nb_router_voice_1_private"):get_player()
            local player_2 = params:lookup_param("nb_router_voice_2_private"):get_player()
            player_1:stop_all()
            player_2:stop_all()
        end
    end

    function player:describe()
        return {
            name = "router",
            supports_bend = false, -- tbd
            supports_slew = false, -- tbd
            note_mod_targets = {}, -- tbd
            modulate_description = nil, -- tbd
            params = {
                "nb_router_voice_1",
                "nb_router_voice_2",
                "nb_router_mode",
                "nb_router_mix",
                "nb_router_xover_note",
                "nb_router_xover_width",
                "nb_router_xover_overlap",
                "nb_router_xover_floor_1",
                "nb_router_xover_floor_2",
            }
        }
    end

    note_players["router"] = player
end

function pre_init()
    if note_players == nil then -- pairing this down to just the essential bit from nb:init()
        note_players = {}
    end
    nb.players = note_players
    add_player()
end

mod.hook.register("script_pre_init", "nb router pre init", pre_init)

-- workaround (in conjunction with voice selector action bang) for text param issue in nb
-- function post_init()

--     -- small delay required before banging params to set nb_player_refcounts and show param groups
--     clock.run(function()
--         clock.sleep(1)
--         params:lookup_param("nb_router_voice_1_private"):bang()
--         params:lookup_param("nb_router_voice_2_private"):bang()
--     end)

-- end

-- mod.hook.register("script_post_init", "nb router post init", post_init)