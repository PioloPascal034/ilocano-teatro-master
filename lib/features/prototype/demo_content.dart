class DemoModule {
  const DemoModule({
    required this.number,
    required this.title,
    required this.description,
    required this.lessons,
    this.tone = 'gold',
  });

  final int number;
  final String title;
  final String description;
  final List<String> lessons;
  final String tone;
}

const demoModules = <DemoModule>[
  DemoModule(
    number: 1,
    title: 'Introduction to Theater',
    description:
        'Discover the language, people, and possibilities of live performance.',
    lessons: [
      'What is Theater?',
      'Elements of Theater',
      'Types and Genres of Theater',
      'Roles in a Theater Production',
    ],
  ),
  DemoModule(
    number: 2,
    title: 'Ilocano Culture & Storytelling',
    description:
        'Listen closely to stories, traditions, and values from Ilocano communities.',
    lessons: [
      'Introduction to Ilocano Literature and Oral Traditions',
      'Ilocano Legends, Epics, and Folktales',
      'Cultural Representation in Theater',
      'Respectful Adaptation of Cultural Stories',
    ],
    tone: 'rust',
  ),
  DemoModule(
    number: 3,
    title: 'Fundamentals of Playwriting',
    description:
        'Shape a story for the stage through plot, character, and dialogue.',
    lessons: [
      'Understanding Plot and Story Structure',
      'Character Development',
      'Dialogue and Stage Directions',
      'Conflict and Resolution',
    ],
    tone: 'blue',
  ),
  DemoModule(
    number: 4,
    title: 'Theater Theme Development',
    description: 'Find the central message that gives your play its heart.',
    lessons: [
      'Understanding a Theatrical Theme',
      'Identifying the Central Message',
      'Connecting Themes with Cultural Stories',
      'Developing Meaningful Dramatic Conflict',
    ],
    tone: 'moss',
  ),
  DemoModule(
    number: 5,
    title: 'Preparing a Stage Play Concept',
    description: 'Bring your ideas together in a clear theatrical concept.',
    lessons: [
      'Identifying the Target Audience',
      'Planning Settings, Props, and Stage Elements',
      'Writing a Theme Statement',
      'Preparing a Theater Concept Note',
    ],
    tone: 'plum',
  ),
];

class DemoStory {
  const DemoStory({
    required this.title,
    required this.category,
    required this.description,
    required this.background,
    required this.source,
    this.verified = true,
  });

  final String title;
  final String category;
  final String description;
  final String background;
  final String source;
  final bool verified;
}

const demoStories = <DemoStory>[
  DemoStory(
    title: 'Biag ni Lam-ang',
    category: 'Epic',
    description:
        'An Ilocano epic centered on Lam-ang, a hero known for extraordinary deeds and adventures.',
    background:
        'A major work in the Ilocano oral literary tradition, documented in collected versions of the epic.',
    source:
        'Isabelo de los Reyes, El Ilocano (1889); National Commission for Culture and the Arts references.',
  ),
  DemoStory(
    title: 'Angalo',
    category: 'Legend',
    description:
        'A creation legend about the giant Angalo and the shaping of the world.',
    background:
        'Versions of the Angalo legend are shared in Ilocano oral tradition and may vary by community.',
    source:
        'National Commission for Culture and the Arts, Philippine mythology resources.',
  ),
  DemoStory(
    title: 'The Aran Cave Story',
    category: 'Folktale',
    description:
        'A sample learning entry for discussing place-based storytelling and local memory.',
    background:
        'Sample content pending review by a subject teacher or cultural source before classroom use.',
    source: 'Attribution pending verification.',
    verified: false,
  ),
  DemoStory(
    title: 'The River and the Weaver',
    category: 'Folktale',
    description:
        'A sample prompt for exploring craft, family, and community in a theatrical adaptation.',
    background:
        'Sample content pending review by a subject teacher or cultural source before classroom use.',
    source: 'Attribution pending verification.',
    verified: false,
  ),
];

class DemoDraft {
  const DemoDraft({
    required this.title,
    required this.student,
    required this.status,
    required this.lastUpdated,
    required this.centralMessage,
    required this.conflict,
    required this.stageConcept,
    this.inspiration = 'Biag ni Lam-ang',
  });

  final String title;
  final String student;
  final String status;
  final String lastUpdated;
  final String centralMessage;
  final String conflict;
  final String stageConcept;
  final String inspiration;
}

const demoDrafts = <DemoDraft>[
  DemoDraft(
    title: 'When the River Speaks',
    student: 'Maria Alvarado',
    status: 'Draft',
    lastUpdated: 'Last updated today',
    centralMessage:
        'Courage grows when a community chooses to help one another.',
    conflict:
        'A young leader must ask for help after pride puts their community at risk.',
    stageConcept:
        'A flexible plaza stage with woven textures and live percussion.',
  ),
  DemoDraft(
    title: 'The Giant’s Promise',
    student: 'Jonas Dela Cruz',
    status: 'Submitted',
    lastUpdated: 'Submitted yesterday',
    centralMessage:
        'Promises have meaning when a community keeps them together.',
    conflict:
        'A village must decide whether to trust a promise that could change its future.',
    stageConcept: 'A minimal stage using shadow, bamboo, and fabric.',
  ),
  DemoDraft(
    title: 'Threads of Home',
    student: 'Aira Santos',
    status: 'Revision Requested',
    lastUpdated: 'Feedback received this week',
    centralMessage:
        'Family histories can help a new generation find belonging.',
    conflict:
        'A young weaver struggles to balance inherited craft with new ambitions.',
    stageConcept:
        'A close, intimate stage with a central loom and warm lighting.',
  ),
];

const demoReviewQueue = <DemoDraft>[
  DemoDraft(
    title: 'When the River Speaks',
    student: 'Maria Alvarado',
    status: 'Submitted',
    lastUpdated: 'Submitted today',
    centralMessage:
        'Courage grows when a community chooses to help one another.',
    conflict:
        'A young leader must ask for help after pride puts their community at risk.',
    stageConcept:
        'A flexible plaza stage with woven textures and live percussion.',
  ),
  DemoDraft(
    title: 'The Giant’s Promise',
    student: 'Jonas Dela Cruz',
    status: 'Submitted',
    lastUpdated: 'Submitted yesterday',
    centralMessage:
        'Promises have meaning when a community keeps them together.',
    conflict:
        'A village must decide whether to trust a promise that could change its future.',
    stageConcept: 'A minimal stage using shadow, bamboo, and fabric.',
  ),
  DemoDraft(
    title: 'Threads of Home',
    student: 'Aira Santos',
    status: 'Revision Requested',
    lastUpdated: 'Revision requested',
    centralMessage:
        'Family histories can help a new generation find belonging.',
    conflict:
        'A young weaver struggles to balance inherited craft with new ambitions.',
    stageConcept:
        'A close, intimate stage with a central loom and warm lighting.',
  ),
];

class DemoNotification {
  const DemoNotification({
    required this.title,
    required this.detail,
    required this.category,
    required this.dateLabel,
    this.isRead = false,
  });

  final String title;
  final String detail;
  final String category;
  final String dateLabel;
  final bool isRead;
}

const demoStudentNotifications = <DemoNotification>[
  DemoNotification(
    title: 'Your theme “Voices of the River” has been reviewed.',
    detail: 'Feedback is ready for you to read.',
    category: 'Submissions',
    dateLabel: '10 min ago',
  ),
  DemoNotification(
    title: 'Your teacher requested revisions to your submitted theme.',
    detail: 'Review the feedback and revise when you are ready.',
    category: 'Submissions',
    dateLabel: 'Yesterday',
  ),
  DemoNotification(
    title: 'Your submission “Letters to Apo” has been approved.',
    detail: 'Wonderful work on your theme concept.',
    category: 'Submissions',
    dateLabel: '2 days ago',
    isRead: true,
  ),
  DemoNotification(
    title: 'You have a new quiz available in Module 2.',
    detail: 'Test your understanding of Ilocano storytelling.',
    category: 'Learning & Reminders',
    dateLabel: '3 days ago',
    isRead: true,
  ),
  DemoNotification(
    title: 'Reminder: Continue your unfinished lesson.',
    detail: 'Elements of Theater is waiting for you.',
    category: 'Learning & Reminders',
    dateLabel: '4 days ago',
    isRead: true,
  ),
];

const demoTeacherNotifications = <DemoNotification>[
  DemoNotification(
    title: 'Maria Alvarado submitted a new theater theme.',
    detail: 'When the River Speaks is ready for review.',
    category: 'New Submissions',
    dateLabel: '10 min ago',
  ),
  DemoNotification(
    title: 'Jonas Dela Cruz resubmitted his revised concept.',
    detail: 'The Giant’s Promise has been updated.',
    category: 'Revisions',
    dateLabel: '1 hour ago',
  ),
  DemoNotification(
    title: 'Three student submissions are awaiting review.',
    detail: 'Review feedback can help students continue their work.',
    category: 'Reminders',
    dateLabel: 'Today',
    isRead: true,
  ),
];

const demoRubric = <(String, String, String)>[
  ('Theme Clarity', '25%', 'Central message is focused and meaningful.'),
  (
    'Conflict and Dramatic Potential',
    '25%',
    'Conflict creates stakes and forward movement.',
  ),
  (
    'Cultural Grounding and Source Acknowledgment',
    '20%',
    'Inspiration is treated respectfully and attributed.',
  ),
  ('Audience Relevance', '15%', 'Concept connects with the intended audience.'),
  (
    'Stage Adaptability',
    '15%',
    'Choices are practical for theatrical presentation.',
  ),
];
