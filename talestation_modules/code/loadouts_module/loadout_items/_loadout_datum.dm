// -- The loadout item datum and related procs. --

/// Global list of ALL loadout datums instantiated.
GLOBAL_LIST_EMPTY(all_loadout_datums)

/**
 * Generate a list of singleton loadout_item datums from all subtypes of [type_to_generate]
 *
 * returns a list of singleton datums.
 */
/proc/generate_loadout_items(type_to_generate)
	RETURN_TYPE(/list)

	. = list()
	if(!ispath(type_to_generate))
		CRASH("generate_loadout_items(): called with an invalid or null path as an argument!")

	for(var/datum/loadout_item/found_type as anything in subtypesof(type_to_generate))
		/// Any item without a name is "abstract"
		if(isnull(initial(found_type.name)))
			continue

		if(!ispath(initial(found_type.item_path)))
			stack_trace("generate_loadout_items(): Attempted to instantiate a loadout item ([initial(found_type.name)]) with an invalid or null typepath! (got path: [initial(found_type.item_path)])")
			continue

		var/datum/loadout_item/spawned_type = new found_type()
		. += spawned_type

/// Loadout item datum.
/// Holds all the information about each loadout items.
/// A list of singleton loadout items are generated on initialize.
/datum/loadout_item
	/// Displayed name of the loadout item.
	var/name
	/// Whether this item has greyscale support.
	/// Only works if the item is compatible with the GAGS system of coloring.
	/// Set automatically to TRUE for all items that have the flag [IS_PLAYER_COLORABLE_1].
	/// If you really want it to not be colorable set this to [DONT_GREYSCALE]
	var/can_be_greyscale = FALSE
	/// Whether this item can be renamed.
	/// I recommend you apply this sparingly becuase it certainly can go wrong (or get reset / overridden easily)
	var/can_be_named = FALSE
	/// Whether this item can be reskinned.
	/// Only works if the item has a "unique reskin" list set.
	var/can_be_reskinned = FALSE
	/// The category of the loadout item.
	var/category
	/// The actual item path of the loadout item.
	var/obj/item/item_path
	/// Lazylist of additional text for the tooltip displayed on this item.
	var/list/additional_tooltip_contents

/datum/loadout_item/New()
	if(can_be_greyscale == DONT_GREYSCALE)
		// Explicitly be false if we don't want this to greyscale
		can_be_greyscale = FALSE
/*
	else if(initial(item_path.flags_1) & IS_PLAYER_COLORABLE_1)
		// Otherwise set this automatically to true if it is actually colorable
		can_be_greyscale = TRUE
		// This means that one can add a greyscale item that does not have player colorable set
		// but is still modifyable as a greyscale item in the loadout menu by setting it to true manually
		// Why? I HAVE NO IDEA why you would do that but you sure can
*/
// Theres literally 0 reason to have this code, it makes having colored items nigh redudnant
// You either get to have all the colored stuff, or a greyscale, or both
// I want both

	if(can_be_named)
		// If we're a renamable item, insert the "renamable" tooltip at the beginning of the list.
		add_tooltip(TOOLTIP_RENAMABLE, inverse_order = TRUE)

	if(can_be_greyscale)
		// Likewise, if we're greyscaleable, insert the "greyscaleable" tooltip at the beginning of the list (before renamable)
		add_tooltip(TOOLTIP_GREYSCALE, inverse_order = TRUE)

	if(can_be_reskinned)
		// No need to repeat myself but I will, insert the reskinnable tooltip at the end if we have a reskin available
		add_tooltip(TOOLTIP_RESKINNABLE)

	if(GLOB.all_loadout_datums[item_path])
		stack_trace("Loadout datum collision detected! [item_path] is shared between multiple loadout datums.")
	GLOB.all_loadout_datums[item_path] = src

/datum/loadout_item/Destroy()
	GLOB.all_loadout_datums -= item_path
	stack_trace("Who's destroying loadout item datums?! This shouldn't really ever be done!")
	return ..()

/// Helper to add a tooltip to our tooltip list.
/// If inverse_order is TRUE, we will add to the front instead of the back.
/datum/loadout_item/proc/add_tooltip(tooltip, inverse_order = FALSE)
	if(!additional_tooltip_contents)
		additional_tooltip_contents = list()

	if(inverse_order)
		additional_tooltip_contents.Insert(1, tooltip)
	else
		additional_tooltip_contents.Add(tooltip)

/**
 * Takes in an action from a loadout manager and applies it
 *
 * Useful for subtypes of loadout items with unique actions
 */
/datum/loadout_item/proc/handle_loadout_action(datum/loadout_manager/manager, action)
	SHOULD_CALL_PARENT(TRUE)

	switch(action)
		if("select_color")
			if(!can_be_greyscale)
				return FALSE

			manager.select_item_color(src)
			return FALSE

		if("set_name")
			if(!can_be_named)
				return FALSE

			manager.set_item_name(src)
			return FALSE

		if("set_skin")
			if(!can_be_reskinned)
				return FALSE

			manager.set_skin(src)
			return TRUE

	return FALSE

/**
 * Place our [var/item_path] into [outfit].
 *
 * By default, just adds the item into the outfit's backpack contents, if non-visual.
 *
 * outfit - The outfit we're equipping our items into.
 * equipper - If we're equipping out outfit onto a mob at the time, this is the mob it is equipped on. Can be null.
 * visual - If TRUE, then our outfit is only for visual use (for example, a preview).
 */
/datum/loadout_item/proc/insert_path_into_outfit(datum/outfit/outfit, mob/living/carbon/human/equipper, visuals_only = FALSE)
	if(!visuals_only)
		LAZYADD(outfit.backpack_contents, item_path)

/**
 * Called When the item is equipped on [equipper].
 *
 * preference_source - the datum/preferences our loadout item originated from - cannot be null
 * equipper - the mob we're equipping this item onto - cannot be null
 * visuals_only - whether or not this is only concerned with visual things (not backpack, not renaming, etc)
 */
/datum/loadout_item/proc/on_equip_item(datum/preferences/preference_source, mob/living/carbon/human/equipper, visuals_only = FALSE, list/preference_list)
	var/obj/item/equipped_item = locate(item_path) in equipper.get_all_contents()
	if(!equipped_item)
		CRASH("[type] on_equip_item(): Could not locate clothing item (path: [item_path]) in [equipper]'s [visuals_only ? "visible":"all"] contents!")

	var/list/item_details = preference_list[item_path]

	if(can_be_greyscale && item_details?[INFO_GREYSCALE])
		equipped_item.set_greyscale(item_details[INFO_GREYSCALE])
		equipper.update_clothing(equipped_item.slot_flags)

	if(can_be_named && item_details?[INFO_NAMED] && !visuals_only)
		equipped_item.name = item_details[INFO_NAMED]
		equipped_item.renamedByPlayer = TRUE

	if(can_be_reskinned && item_details?[INFO_RESKIN])
		var/skin_chosen = item_details[INFO_RESKIN]
		if(skin_chosen in equipped_item.unique_reskin)
			equipped_item.current_skin = skin_chosen
			equipped_item.icon_state = equipped_item.unique_reskin[skin_chosen]
			equipper.update_worn_oversuit()
		else
			// Not valid
			item_details -= INFO_RESKIN
			preference_source.write_preference(GLOB.preference_entries[/datum/preference/loadout], preference_list)

	return equipped_item

/**
 * Called after the item is equipped on [equipper], at the end of character setup.
 *
 * preference_source - the datum/preferences our loadout item originated from - cannot be null
 * equipper - the mob we're equipping this item onto - cannot be null
 */
/datum/loadout_item/proc/post_equip_item(datum/preferences/preference_source, mob/living/carbon/human/equipper)
	return FALSE
