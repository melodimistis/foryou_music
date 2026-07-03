import 'dart:math';

class Greetings {
  static String getRandomGreeting() {
    final hour = DateTime.now().hour;
    final random = Random();

    final List<String> morningGreetings = [
      "hello, good morning!",
      "did you sleep well?",
      "lets start the day with some music :)",
      "dont forget your coffee, mate",
      "whats playlist you wanna start with today?",
    ];

    final List<String> afternoonGreetings = [
      "hows your day so far?",
      "take a break and enjoy a song with me :D",
      "dont forget your lunch, buddy",
      "lets make this afternoon productive with some music",
    ];

    final List<String> nightGreetings = [
      "hello, hows your day?",
      "its okay, im here for you /patpat",
      "need company? lets listen to some music together <3",
      "good night, sleep well okayy?????",
      "is you find a good thing today?",
      "i would like to say that you did a good job today, keep it up friend!",
      "dont feel lonely, im here :3",
    ];

    if (hour >= 5 && hour < 12) {
      return morningGreetings[random.nextInt(morningGreetings.length)];
    } else if (hour >= 12 && hour < 18) {
      return afternoonGreetings[random.nextInt(afternoonGreetings.length)];
    } else {
      return nightGreetings[random.nextInt(nightGreetings.length)];
    }
  }
}
