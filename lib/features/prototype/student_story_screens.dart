import 'package:flutter/material.dart';

import '../../app/app_routes.dart';
import '../../app/app_theme.dart';
import '../../core/widgets/teatro_widgets.dart';
import 'demo_content.dart';
import 'prototype_widgets.dart';

class StoryVaultScreen extends StatefulWidget {
  const StoryVaultScreen({
    required this.onOpenStory,
    required this.onNavigate,
    super.key,
  });

  final ValueChanged<DemoStory> onOpenStory;
  final ValueChanged<AppDestination> onNavigate;

  @override
  State<StoryVaultScreen> createState() => _StoryVaultScreenState();
}

class _StoryVaultScreenState extends State<StoryVaultScreen> {
  final _searchController = TextEditingController();
  String _filter = 'All';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DemoStory> get _visibleStories => demoStories.where((story) {
    final matchesFilter = _filter == 'All' || story.category == _filter;
    final matchesQuery =
        '${story.title} ${story.description} ${story.background}'
            .toLowerCase()
            .contains(_query.toLowerCase());
    return matchesFilter && matchesQuery;
  }).toList();

  @override
  Widget build(BuildContext context) => DemoPageBody(
    eyebrow: 'CULTURAL STORYTELLING',
    title: 'Ilocano Story Vault',
    description:
        'A learning collection for respectful theme inspiration. Entries marked sample require source review before classroom use.',
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final search = SizedBox(
              width: compact ? double.infinity : 380,
              child: DemoSearchField(
                controller: _searchController,
                hint: 'Search stories',
                onChanged: (value) => setState(() => _query = value),
              ),
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 10),
                      DemoFilterTabs(
                        labels: const ['All', 'Epic', 'Legend', 'Folktale'],
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 13),
                      DemoFilterTabs(
                        labels: const ['All', 'Epic', 'Legend', 'Folktale'],
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                      ),
                    ],
                  );
          },
        ),
        const SizedBox(height: 17),
        if (_visibleStories.isEmpty)
          const DemoEmptyState(
            title: 'No stories match this search',
            description: 'Try another story title or category.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth <= 700
                  ? 1
                  : constraints.maxWidth <= 1050
                  ? 2
                  : 3;
              return GridView.builder(
                itemCount: _visibleStories.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: columns == 1 ? 320 : 310,
                ),
                itemBuilder: (context, index) => _StoryCard(
                  story: _visibleStories[index],
                  onRead: () => widget.onOpenStory(_visibleStories[index]),
                  onUse: () => widget.onNavigate(AppDestination.themeBuilder),
                ),
              );
            },
          ),
      ],
    ),
  );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.story,
    required this.onRead,
    required this.onUse,
  });

  final DemoStory story;
  final VoidCallback onRead;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) => TeatroCard(
    padding: const EdgeInsets.all(19),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: story.verified
                    ? const Color(0xFFE8EFE1)
                    : const Color(0xFFF5E3D8),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: story.verified
                    ? TeatroColors.success
                    : TeatroColors.rust,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TeatroEyebrow(
                story.verified ? story.category : '${story.category} · SAMPLE',
                color: story.verified ? TeatroColors.muted : TeatroColors.rust,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          story.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Text(
            story.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: TeatroColors.muted),
          ),
        ),
        Text(
          story.source,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: TeatroColors.muted,
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 7,
          children: [
            DemoActionButton(
              label: 'Read story',
              icon: Icons.menu_book_outlined,
              onPressed: onRead,
            ),
            TextButton.icon(
              onPressed: onUse,
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: const Text('Use as inspiration'),
              style: TextButton.styleFrom(foregroundColor: TeatroColors.rust),
            ),
          ],
        ),
      ],
    ),
  );
}

class StoryDetailsScreen extends StatelessWidget {
  const StoryDetailsScreen({
    required this.story,
    required this.onBack,
    required this.onUseAsInspiration,
    super.key,
  });

  final DemoStory story;
  final VoidCallback onBack;
  final ValueChanged<String> onUseAsInspiration;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 850),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DemoBackButton(label: 'Story Vault', onPressed: onBack),
        const DemoDataNotice(),
        TeatroEyebrow(
          '${story.category.toUpperCase()} · ${story.verified ? 'VERIFIED LEARNING ENTRY' : 'SAMPLE · SOURCE REVIEW NEEDED'}',
          color: TeatroColors.rust,
        ),
        const SizedBox(height: 6),
        Text(story.title, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 18),
        TeatroCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                story.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 22),
              Text(
                'Cultural background',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                story.background,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 22),
              Text(
                'Source & attribution',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                story.source,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EEE0),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'This entry is for educational exploration. Consult teacher-approved materials when adapting cultural stories for performance.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        DemoPrimaryButton(
          label: 'Use as theme inspiration',
          icon: Icons.arrow_forward,
          onPressed: () => onUseAsInspiration(story.title),
        ),
      ],
    ),
  );
}
