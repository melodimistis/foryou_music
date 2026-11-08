import 'dart:math';

enum DayPart { morning, afternoon, evening, night }

class Greetings {
  Greetings._();

  static const lines = <DayPart, List<String>>{
    DayPart.morning: [
      'good morningg!',
      'did you sleep well?',
      'lets start the day with some music :)',
      'dont forget your coffee, mate',
      'whats playlist you wanna start with today?',
    ],
    DayPart.afternoon: [
      'hows your day so far?',
      'take a break and enjoy a song with me :D',
      'dont forget your lunch, buddy',
      'lets make this afternoon productive with some music',
    ],
    DayPart.evening: [
      'the sun is going down, lets slow down with a song',
      'golden hour needs a soundtrack, right?',
      'almost done for today, keep going!',
      'how was your day? tell me with a song',
    ],
    DayPart.night: [
      'hello, hows your day?',
      'its okay, im here for you /patpat',
      'need company? lets listen to some music together <3',
      'good night, sleep well okayy?????',
      'is you find a good thing today?',
      'i would like to say that you did a good job today, keep it up friend!',
      'dont feel lonely, im here :3',
    ],
  };

  static DayPart partOf(DateTime time) {
    final h = time.hour;
    if (h >= 5 && h < 11) return DayPart.morning;
    if (h >= 11 && h < 15) return DayPart.afternoon;
    if (h >= 15 && h < 18) return DayPart.evening;
    return DayPart.night;
  }

  static String random({DateTime? now, Random? random}) {
    final options = lines[partOf(now ?? DateTime.now())]!;
    return options[(random ?? Random()).nextInt(options.length)];
  }
}
