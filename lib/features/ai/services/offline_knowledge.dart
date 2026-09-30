/// What the assistant can still answer with no signal.
///
/// The offline fallback used to return one-line flavour text — "Hydration
/// priority", "Stay calm. Focus." — which is exactly the "generic, canned"
/// problem. Out of range is precisely when someone needs a real answer, so
/// this holds actual field information instead.
///
/// Safety content follows Australian first-aid practice (St John / Australian
/// Resuscitation Council) for the things most likely to go wrong in the WA
/// outback. Where the right answer is "do not guess", it says so.
library;

class FieldAnswer {
  const FieldAnswer({
    required this.topic,
    required this.keywords,
    required this.answer,
    this.urgent = false,
  });

  final String topic;

  /// Lower-case words that point at this topic.
  final List<String> keywords;

  final String answer;

  /// Life-threatening topics lead with the action, not the explanation.
  final bool urgent;
}

const List<FieldAnswer> kFieldKnowledge = [
  FieldAnswer(
    topic: 'Snake bite',
    urgent: true,
    keywords: ['snake', 'snakebite', 'bitten', 'venom', 'brown snake',
        'mulga', 'death adder', 'taipan'],
    answer: '''SNAKE BITE — treat every bite as venomous.

1. Keep them still. Movement pumps venom through the body. Do not let them walk if you can avoid it.
2. Pressure immobilisation: firm broad bandage over the bite, then bandage the whole limb from fingers or toes upward, as tight as a sprain strap. Splint the limb so it cannot bend.
3. Mark the bite site on the outside of the bandage and write the time.
4. Call 000. If there is no signal, send an SOS from this app and stay put — rescue comes to you.

Do NOT wash the bite (venom on the skin helps identify the snake), do NOT cut it, do NOT suck it, do NOT use a tourniquet, do NOT chase the snake.

Most Australian snake bites do not inject much venom, and people who stay still do well. Panic and walking are what kill.''',
  ),
  FieldAnswer(
    topic: 'Heat and dehydration',
    urgent: true,
    keywords: ['heat', 'hot', 'dehydrated', 'dehydration', 'heatstroke',
        'heat stroke', 'exhaustion', 'sunstroke', 'cramps', 'overheating',
        'sweating', 'stopped sweating', 'confused', 'dizzy', 'heat exhaustion'],
    answer: '''HEAT ILLNESS — the difference matters.

Heat exhaustion: heavy sweating, pale, weak, dizzy, headache, nausea. Get into shade, lie down, raise the legs, sip water, loosen clothing, wet the skin and fan.

Heat stroke: hot skin, sweating may STOP, confused, stumbling, aggressive or unconscious. This kills. Cool them however you can — water over the body, wet cloth, fan, shade — and send for help immediately. Do not wait to see if they improve.

Prevention beats both: move at dawn and dusk, rest through the middle of the day, stay covered rather than stripping off, and drink before you are thirsty.''',
  ),
  FieldAnswer(
    topic: 'Water',
    keywords: ['water', 'thirsty', 'drink', 'drinking', 'hydration', 'ration',
        'bore', 'soak', 'creek', 'tank'],
    answer: '''WATER — the first thing to run out and the first thing to kill you.

In outback heat expect to need 4-6 litres a day doing very little, and more if you are working or walking. Drink steadily; gulping a lot at once mostly passes straight through.

Do not ration water while you still have it and no plan to get more — being dehydrated with a full bottle is a common way people die. Ration your SWEAT instead: stay in shade, move at night, keep clothes on so it evaporates off the fabric, not out of you.

Water sources out here: station bores and tanks (usually drinkable, sometimes salty), rock holes and soaks after rain, and creek pools. Treat anything you did not carry in — boil if you can, filter if you cannot, and remember that dead stock near a pool means leave it.

Never drink radiator coolant, urine or seawater.''',
  ),
  FieldAnswer(
    topic: 'Lost',
    urgent: true,
    keywords: ['lost', 'no idea where', 'disoriented', 'turned around',
        'cant find', "can't find", 'which way'],
    answer: '''LOST — stop before you make it worse.

STOP: Sit down. Think. Observe. Plan. Most people get properly lost in the twenty minutes after they first suspect it, by walking fast in the wrong direction.

1. Stay where you are if anyone knows roughly where you went. You are easier to find than to catch.
2. Check this app — your breadcrumb trail shows exactly how you got here, and Retrace walks it back.
3. If nobody knows where you are, do not wander. Get visible: open ground, high ground, big markings, smoke.
4. Send an SOS from this app. It reaches other phones running BushTrack nearby even with no mobile signal.

Walking out is a last resort, and only with a known direction, water, and daylight ahead of you.''',
  ),
  FieldAnswer(
    topic: 'Vehicle breakdown',
    urgent: true,
    keywords: ['breakdown', 'broke down', 'car', 'vehicle', 'ute', 'bogged',
        'stranded', 'flat tyre', 'engine'],
    answer: '''BROKEN DOWN — stay with the vehicle.

A vehicle is shade, shelter, water storage, a signal, and a thing search aircraft can actually see. People who walk away from vehicles are the ones who are found too late.

1. Get out of the sun but not inside a closed cab — it gets hotter than outside. Rig shade off the side, sit in the shadow, put something between you and the ground.
2. Inventory water first, then food, then anything that can signal.
3. Raise the bonnet, and lay out anything bright or reflective in a big pattern on open ground.
4. Send an SOS from this app and leave it running. Conserve phone battery otherwise.
5. Run the engine sparingly if you need the radio or to charge.

If you genuinely must leave, write a note with the time, your direction, and how much water you took, and leave it on the steering wheel.''',
  ),
  FieldAnswer(
    topic: 'Signalling for rescue',
    keywords: ['signal', 'rescue', 'help', 'flare', 'mirror', 'smoke',
        'aircraft', 'plane', 'search'],
    answer: '''BEING FOUND — make yourself big and wrong-looking.

Three of anything means distress: three fires, three whistle blasts, three flashes.

- Mirror or phone screen: aim the flash at aircraft. A mirror is visible for tens of kilometres and costs no battery.
- Smoke: green leaves or rubber on a fire gives dark smoke; smoke is the best daytime signal in open country.
- Ground markings: stamp or lay out letters at least 3 metres across in an open clear area. A V means assistance required. An X means medical help needed.
- Straight lines and right angles do not occur in nature — that is what spotters are trained to notice.

Movement catches the eye: wave something bright, do not just stand there.''',
  ),
  FieldAnswer(
    topic: 'Navigation without GPS',
    keywords: ['north', 'direction', 'bearing', 'compass', 'navigate',
        'without gps', 'sun', 'stars', 'southern cross'],
    answer: '''FINDING DIRECTION WITHOUT GPS

Sun: it rises roughly east and sets roughly west. At solar noon in Australia it sits due NORTH, so your shadow points south.

Shadow stick: push a stick upright, mark the shadow tip, wait 15 minutes, mark it again. The line between the marks runs roughly west to east, first mark being west.

Night: find the Southern Cross and the two Pointer stars. Extend the long axis of the Cross about four and a half times its length; drop straight down from that point to the horizon — that is south.

Compass: the compass in this app works on the phone's magnetometer. Hold the phone flat and away from the vehicle, and tap the compass at the bottom right to enable it. Metal and speakers throw it out.''',
  ),
  FieldAnswer(
    topic: 'Shelter',
    keywords: ['shelter', 'shade', 'camp', 'sleep', 'tent', 'swag', 'night',
        'bivvy'],
    answer: '''SHELTER — shade by day, insulation by night.

Day: shade is survival, not comfort. Anything solid overhead beats none; a tarp rigged with an air gap above it is far cooler than one lying on you. Do not lie directly on hot ground — get something between you and it.

Night: the desert loses heat fast and clear nights get genuinely cold. Ground steals more heat than air, so insulate underneath before you pile things on top.

Siting camp: flat, out of the wind, on higher ground. Never in a dry creek bed — water arrives hours after rain you never saw, in a place you cannot outrun. Keep away from lone trees in a storm and check overhead for dead limbs.''',
  ),
  FieldAnswer(
    topic: 'Bleeding',
    urgent: true,
    keywords: ['bleeding', 'blood', 'cut', 'wound', 'laceration', 'gash'],
    answer: '''SERIOUS BLEEDING

1. Firm direct pressure straight on the wound with whatever you have. Hands will do.
2. Keep pressing. Do not lift it to check — that restarts the bleed. If it soaks through, add more on top.
3. Raise the limb above the heart if you can.
4. Lie them down and keep them warm; shock kills after the bleeding stops.
5. Call 000, or SOS from this app if there is no signal.

A tourniquet is for limb bleeding you cannot stop any other way — high, tight, and write the time on them. Once on, it stays on until a medic takes it off.''',
  ),
  FieldAnswer(
    topic: 'Burns',
    keywords: ['burn', 'burnt', 'burned', 'scald', 'fire injury'],
    answer: '''BURNS

Cool running water for 20 minutes. Not ice, not butter, not creams. Twenty minutes is the number — it keeps working up to three hours after the burn.

Take rings and watches off before swelling starts. Cover loosely with clean non-fluffy material or cling film laid on, not wrapped tight.

Get help for burns that are bigger than a palm, on the face, hands, feet or genitals, or that look white, leathery or painless — painless usually means deep.''',
  ),
  FieldAnswer(
    topic: 'Broken bones and sprains',
    keywords: ['broken', 'fracture', 'sprain', 'ankle', 'arm', 'leg',
        'splint', 'twisted'],
    answer: '''FRACTURES AND SPRAINS

Do not straighten or push anything back. Immobilise it in the position you found it, splinting to the joint above and below with anything rigid and padding the gaps.

Check fingers or toes past the injury stay warm and pink; if they go cold or blue, the splint is too tight.

Sprains: rest, something cold if you have it, firm bandage, elevate. If they cannot put weight through it at all, treat it as a fracture until someone qualified says otherwise.''',
  ),
  FieldAnswer(
    topic: 'Cold nights and hypothermia',
    keywords: ['cold', 'freezing', 'hypothermia', 'shivering', 'frost'],
    answer: '''COLD — yes, out here too.

Clear outback nights drop near or below zero, and people caught out in day clothes get into trouble because they were hot eight hours earlier.

Signs: uncontrolled shivering, then clumsiness, slurred speech, and confusion. When the shivering STOPS and they are still cold, that is serious.

Get them out of wind, off the ground, out of wet clothes, and insulated on all sides. Warm sweet drinks if they are fully alert. No alcohol. Handle them gently and do not rub their limbs.''',
  ),
  FieldAnswer(
    topic: 'Spiders, scorpions and insects',
    keywords: ['spider', 'redback', 'scorpion', 'sting', 'bee', 'wasp',
        'centipede', 'ant', 'insect'],
    answer: '''BITES AND STINGS

Redback: painful, gets worse over hours, rarely dangerous. Ice pack, keep still, seek help if the pain spreads or they are very young or very old. Do NOT use a pressure bandage.

Funnel-web (east coast, not WA): pressure immobilisation, same as snake bite, treat as an emergency.

Scorpions, centipedes, ants, bees: painful, mostly not dangerous. Cold pack and pain relief. Scrape a bee sting out sideways, do not pinch it.

Anyone at all, any sting: if they get a swollen face or tongue, a rash all over, wheezing or trouble breathing, that is anaphylaxis. Adrenaline autoinjector if there is one, lie them flat, 000 or SOS, and do not let them stand up.''',
  ),
  FieldAnswer(
    topic: 'Fire',
    keywords: ['fire', 'firewood', 'matches', 'light a fire', 'campfire',
        'burn off'],
    answer: '''FIRE

Clear a three-metre circle to bare dirt and check what is overhead. Have water or sand ready before you light it.

Build small: a fire you can cook and signal on, not one that gets away. Dry mulga and dead spinifex catch fast; spinifex especially burns hot and spreads faster than you can run.

Check fire restrictions and total fire bans before lighting anything. On a Total Fire Ban day, do not light one at all.

Put it out properly — drown, stir, drown again, and feel it with the back of your hand. Coals hold heat for a very long time under the surface.''',
  ),
  FieldAnswer(
    topic: 'Flooded creek crossings',
    keywords: ['flood', 'flooded', 'crossing', 'washaway', 'river',
        'water over', 'across the road', 'cross the creek'],
    answer: '''FLOODED CROSSINGS — do not drive into it.

Moving water 30 cm deep can float a car; 60 cm will move a 4WD. You cannot see whether the road under it is still there, and washaways happen exactly at crossings.

Rain a hundred kilometres away puts water across a road under a blue sky here. Wait. These flows usually drop within hours.

If you are already in it and stalling, get out and upstream of the vehicle while you still can.''',
  ),
  FieldAnswer(
    topic: 'Dust storms',
    keywords: ['dust', 'dust storm', 'sandstorm', 'haboob', 'visibility'],
    answer: '''DUST STORM

Driving: get off the road, not just onto the shoulder. Turn lights OFF once stopped — cars behind follow tail-lights straight into you. Stay in the vehicle with the windows up and vents closed.

On foot: put something over your mouth and nose, damp if possible. Goggles or sunglasses. Get to the downwind side of anything solid and sit it out with your back to the wind.

Mark your position in the app before visibility goes. They usually pass in under an hour and everything looks different afterwards.''',
  ),
  FieldAnswer(
    topic: 'Food and foraging',
    keywords: ['food', 'eat', 'eating', 'hungry', 'forage', 'bush tucker',
        'plants', 'berries'],
    answer: '''FOOD — the least urgent of your problems.

You can go weeks without food and days without water. Do not burn water and energy hunting for food in the first day or two.

Do not experiment with unfamiliar plants. Plenty of Australian bush plants are toxic, several look like things that are not, and some need specific preparation before they are safe. Being sick costs you water you cannot spare.

If you have not been shown a plant by someone who knows it, leave it. What is worth doing: stay in shade, keep drinking, and put your effort into being found.''',
  ),
  FieldAnswer(
    topic: 'Phone and battery',
    keywords: ['battery', 'phone', 'charge', 'power', 'flat', 'dying',
        'conserve'],
    answer: '''MAKING THE BATTERY LAST

Your phone is a map, a compass, a signalling mirror and an SOS beacon. Treat it as survival gear.

- Aeroplane mode when you are not signalling. Hunting for a tower it cannot find is what flattens phones fastest.
- Screen brightness down, and screen off between checks.
- Keep it out of direct sun and off hot surfaces. Heat damages the battery permanently and shuts the phone down.
- In the cold, keep it against your body — cold batteries read flat and recover when warm.

This app works fully offline once map regions are downloaded, so you do not need signal to navigate.''',
  ),
  FieldAnswer(
    topic: 'Using this app',
    keywords: ['app', 'bushtrack', 'pinage', 'feature', 'button',
        'zone', 'pin', 'file', 'trail', 'sos button', 'this app'],
    answer: '''WHAT THIS APP DOES

- Pins: long-press the map to drop one. Tap a pin for distance and bearing from you, and Track to be guided to it.
- Zones: Draw Zone in the menu. Circles, or tap out a boundary corner by corner around a hazard, a heritage site or a work area. You get told when you cross in or out.
- Files: the folder button up top. While a file is open, every note, pin and zone you make is filed under it.
- Trails: record where you walked or drove, and retrace it back.
- Compass: bottom right. Tap it to enable.
- SOS: top right, hold three seconds. Sends your position to nearby phones running this app over the mesh, with no mobile signal needed.
- Offline maps: download a region before you head out and the map keeps working with no signal.''',
  ),
];

/// The best matching topic for [question], or null when nothing fits.
///
/// Scores on whole-word keyword hits so "water" does not match "saltwater
/// crocodile" style near misses, with a bonus for longer keywords because
/// "snake bite" is a stronger signal than "bite".
FieldAnswer? matchFieldAnswer(String question) {
  final text = question.toLowerCase();
  FieldAnswer? best;
  var bestScore = 0;

  for (final entry in kFieldKnowledge) {
    var score = 0;
    for (final keyword in entry.keywords) {
      if (!_containsWord(text, keyword)) continue;
      // Multi-word keywords are far more specific than single words.
      score += keyword.contains(' ') ? 5 : (keyword.length >= 6 ? 3 : 2);
    }
    if (entry.urgent && score > 0) score += 1;
    if (score > bestScore) {
      bestScore = score;
      best = entry;
    }
  }
  return best;
}

/// Whole-word match, so "sweating" does not count as "eat" and "want" does
/// not count as "ant". Plain substring matching sent "he stopped sweating"
/// to the foraging topic.
bool _containsWord(String text, String keyword) {
  final escaped = RegExp.escape(keyword);
  return RegExp('(?<![a-z0-9])$escaped(?![a-z0-9])').hasMatch(text);
}

/// Everything the assistant can answer without a signal, for when it cannot
/// match the question — better than "Ready to help."
String offlineTopicList() {
  final topics = kFieldKnowledge.map((e) => e.topic).join(', ');
  return "I'm offline, so I'm working from what's stored on the phone rather "
      "than the full assistant. I can still help with: $topics.\n\n"
      "Ask me about any of those, or say what's happening and I'll match it.";
}

/// The offline answer to [question], with whatever live context is worth
/// adding. This is what the assistant says when there is no signal.
String buildOfflineAnswer(String question, [Map<String, dynamic>? context]) {
  final match = matchFieldAnswer(question);
  final buffer = StringBuffer();

  if (match == null) {
    buffer.write(offlineTopicList());
  } else {
    buffer.write(match.answer);
  }

  // Position is the one thing the assistant knows that a book does not, and
  // it is the thing rescuers ask for first.
  final lat = context?['latitude'] ?? context?['current_lat'];
  final lon = context?['longitude'] ?? context?['current_lon'];
  if (lat is num && lon is num) {
    buffer.write('\n\nYour position right now: '
        '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}. '
        'Read those numbers out if you get anyone on the radio or the phone.');
  }

  return buffer.toString();
}
