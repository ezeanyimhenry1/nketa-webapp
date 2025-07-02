final List<Map<String, String>> proverbs = [
  {
    'igbo': 'Egbe belu, ugo belu. Nke si ibe ya ebela, nku kwa ya.',
    'english':
        'Let the kite perch and let the eagle perch. Whichever says the other should not perch, may its wings break.',
  },
  {
    'igbo': 'A na-agwa ntị ma ntị anụghị, e gburu isi ntị esoro ya.',
    'english':
        'When advice is given to the ear and the ear refuses to listen, when the head is cut off, the ear follows.',
  },
  {
    'igbo': 'Ihe onye metere ya ga-ata ya.',
    'english': 'Whatever a person does will come back to them.',
  },
  {
    'igbo': 'O bu onye nwe ya na-ebu ya.',
    'english': 'It is the owner that carries their own burden.',
  },
  {
    'igbo': 'Okwu a tụụrụ n\'ụlọ ka e jiri mara dike n\'agha.',
    'english':
        'The words spoken at home are what is used to judge a warrior in battle.',
  },
  {
    'igbo': 'Nwata bulie nna ya elu, ogodo ya ana ada.',
    'english': 'When a child lifts up their father, their own cloth falls off.',
  },
  {
    'igbo': 'Onye buru chi ya ụzọ, ọ gbagbue onwe ya n\'ụzọ.',
    'english': 'Whoever goes before their god, destroys themselves on the way.',
  },
  {
    'igbo': 'A sị na agwọ gbalụo ogwu, ọ gaghị egbu ya.',
    'english':
        'If a snake runs away from medicine, it will not be killed by it.',
  },
  {
    'igbo': 'Onye na-amaghị ebe mmiri bidoro mawa ya, ama ama ya agwụla.',
    'english':
        'He who does not know where the rain began to beat him, will not know where it dried his body.',
  },
  {
    'igbo': 'A kpụkpọrọ akpụkpọ, a mara onye nwe ya.',
    'english': 'When a skin is flayed, the owner is known.',
  },
];

Map<String, String> getProverbOfTheDay() {
  final todayIndex =
      DateTime.now().difference(DateTime(2024, 1, 1)).inDays % proverbs.length;
  return proverbs[todayIndex];
}
