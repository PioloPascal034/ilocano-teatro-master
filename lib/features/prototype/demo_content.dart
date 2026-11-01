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
