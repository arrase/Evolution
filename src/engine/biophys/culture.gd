class_name EvoCulture
extends RefCounted

## Trait compatibility and horizontal cultural transmission between trading partners.


static func can_acquire_trait(deme: EvoTypes.Deme, trait_id: String, traits_catalog: Dictionary) -> bool:
	if deme.cultural_trait_ids.has(trait_id) or deme.biological_trait_ids.has(trait_id):
		return false
	var tdef: EvoTypes.TraitDef = traits_catalog[trait_id]
	for existing_id in deme.biological_trait_ids + deme.cultural_trait_ids:
		var existing: EvoTypes.TraitDef = traits_catalog[existing_id]
		if tdef.mutually_exclusive_with.has(existing_id) or existing.mutually_exclusive_with.has(trait_id):
			return false
	return true


## The receiver adopts the first donor tradition its social cohesion can absorb.
static func diffuse(donor: EvoTypes.Deme, receiver: EvoTypes.Deme, state: EvoTypes.WorldState, lang: String) -> void:
	if not EvoCatalog.deme_has_cultural_capacity(receiver, state.traits_catalog):
		return
	var cohesion := EvoPayoffs.vector(receiver, state).social_cohesion
	for tid in donor.cultural_trait_ids:
		var tdef: EvoTypes.TraitDef = state.traits_catalog[tid]
		if not can_acquire_trait(receiver, tid, state.traits_catalog) or cohesion < tdef.vector.transmission_threshold:
			continue
		receiver.cultural_trait_ids.append(tid)
		EvoTypes.push_event(state, "symbiosis", donor.hex_id, receiver.hex_id, donor.id, receiver.id, 1.0, 0)
		var tname := EvoI18n.trait_name(lang, tdef)
		var is_en := lang == "en"
		var entry := EvoTypes.ChronicleEntry.new()
		entry.id = "chronicle-symbiosis-%d-%s-%s" % [state.generation, receiver.id, tid]
		entry.generation = state.generation
		entry.event_type = "symbiosis"
		entry.title = ("Cultural Symbiosis: %s" if is_en else "Simbiosis Cultural: %s") % tname
		entry.causal_explanation = (
			"%s acquired %s through trade with %s." % [receiver.name, tname, donor.name]
			if is_en
			else "%s adquirió %s mediante el comercio con %s." % [receiver.name, tname, donor.name]
		)
		entry.hex_id = receiver.hex_id
		entry.deme_id = receiver.id
		entry.lineage_id = receiver.lineage_id
		entry.trait_id = tid
		state.chronicle.append(entry)
		EvoRelations.remember(receiver, state, "Adopted the %s tradition from %s." % [tdef.name, donor.name])
		return
