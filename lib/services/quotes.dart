// Bundled stoic / one-liner corpus. Offline, no fetch.
// Seeded curated set — expand by appending to kQuotes. `ponytail:` ceiling:
// small corpus now, grow over time; on-device model tuning is v0.2.

class Quote {
  final String text;
  final String author;
  const Quote(this.text, this.author);
}

const List<Quote> kQuotes = [
  Quote('You have power over your mind, not outside events. Realize this, and you will find strength.', 'Marcus Aurelius'),
  Quote('We suffer more often in imagination than in reality.', 'Seneca'),
  Quote('It is not that we have a short time to live, but that we waste a lot of it.', 'Seneca'),
  Quote('The obstacle is the way.', 'Marcus Aurelius'),
  Quote('Waste no more time arguing about what a good man should be. Be one.', 'Marcus Aurelius'),
  Quote('He who fears death will never do anything worthy of a man who is alive.', 'Seneca'),
  Quote('No man is free who is not master of himself.', 'Epictetus'),
  Quote('First say to yourself what you would be; and then do what you have to do.', 'Epictetus'),
  Quote('Difficulty shows what men are.', 'Epictetus'),
  Quote('Man conquers the world by conquering himself.', 'Zeno of Citium'),
  Quote('Luck is what happens when preparation meets opportunity.', 'Seneca'),
  Quote('The best revenge is to be unlike him who performed the injury.', 'Marcus Aurelius'),
  Quote('When you arise in the morning, think of what a precious privilege it is to be alive.', 'Marcus Aurelius'),
  Quote('Begin at once to live, and count each separate day as a separate life.', 'Seneca'),
  Quote('It is not the man who has too little, but the man who craves more, that is poor.', 'Seneca'),
  Quote('What is to give light must endure burning.', 'Viktor Frankl'),
  Quote('He who is brave is free.', 'Seneca'),
  Quote('The greatest wealth is to live content with little.', 'Plato'),
  Quote('Discipline is the bridge between goals and accomplishment.', 'Jim Rohn'),
  Quote('You cannot swim for new horizons until you have courage to lose sight of the shore.', 'William Faulkner'),
  Quote('We are what we repeatedly do. Excellence, then, is not an act, but a habit.', 'Aristotle'),
  Quote('The impediment to action advances action. What stands in the way becomes the way.', 'Marcus Aurelius'),
  Quote('It is not what happens to you, but how you react to it that matters.', 'Epictetus'),
  Quote('Better to trip with the feet than with the tongue.', 'Zeno of Citium'),
  Quote('The whole future lies in uncertainty: live immediately.', 'Seneca'),
  Quote('One day, or day one. You decide.', 'Anonymous'),
  Quote('Action breeds confidence and courage. Inaction breeds doubt and fear.', 'Dale Carnegie'),
  Quote('Guard your time jealously. It is all you truly have.', 'imperium'),
  Quote('A clear conscience is a soft pillow.', 'French proverb'),
  Quote('Fortune favors the bold.', 'Latin proverb'),
  Quote('A man is what he does with himself.', 'Seneca'),
  Quote('Happiness is a good flow of life.', 'Zeno of Citium'),
  Quote('The boundary of your what is nothing but your will.', 'imperium'),
  Quote('Quietly endure, bravely act.', 'Marcus Aurelius'),
  Quote('Make each day your masterpiece.', 'John Wooden'),
  Quote('Standing still is the surest way to be left behind.', 'imperium'),
];

/// Rotates by day + mood. Deterministic for a given seed.
Quote dailyQuote(DateTime day, {String? moodTag}) {
  var seed = day.millisecondsSinceEpoch ~/ 86400000;
  if (moodTag != null) seed += moodTag.hashCode;
  return kQuotes[seed % kQuotes.length];
}
