// Mindora - Professional Caregiver Dashboard
// Designed for family caregivers and care partners to view wellness and activity
// summaries shared with their explicit consent.
// Strictly conforms to medical dignity standards: NEVER uses the word "Patient".
// All values come from the backend caregiver API; nothing is hard-coded.

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'theme/mindora_theme.dart';
import 'app_settings.dart';
import 'services/api_service.dart';
import 'widgets/logout_button.dart';

class CaregiverPortal extends StatefulWidget {
  const CaregiverPortal({super.key});

  @override
  State<CaregiverPortal> createState() => _CaregiverPortalState();
}

class _CaregiverPortalState extends State<CaregiverPortal> {
  bool _loading = true;
  bool _pairing = false;
  String? _error;
  Map<String, dynamic>? _dashboard;
  List<dynamic> _lovedOnes = const [];
  int? _selectedUserId;

  String tr(String en, String hi, {String? key}) =>
      AppSettings.instance.trBilingual(en, hi, key: key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final api = ApiService.instance;
    if (!api.isAuthenticated || !api.isCaregiver) {
      setState(() {
        _loading = false;
        _error = tr(
          'Please sign in with a caregiver account to view this portal.',
          'कृपया यह पोर्टल देखने के लिए देखभालकर्ता खाते से साइन इन करें।',
        );
      });
      return;
    }

    final lovedOnes = await api.fetchLovedOnes();
    if (!mounted) return;
    if (lovedOnes == null) {
      setState(() {
        _loading = false;
        _error = api.lastError ??
            tr('Could not reach the server. Please try again.',
                'सर्वर से संपर्क नहीं हो सका। कृपया पुनः प्रयास करें।');
      });
      return;
    }

    final selected = _selectedUserId != null &&
            lovedOnes.any((e) => e is Map && e['user_id'] == _selectedUserId)
        ? _selectedUserId
        : (lovedOnes.isNotEmpty && lovedOnes.first is Map
            ? lovedOnes.first['user_id'] as int?
            : null);

    Map<String, dynamic>? dashboard;
    String? loadError;
    if (selected != null) {
      dashboard = await api.fetchCaregiverDashboard(userId: selected);
      if (dashboard == null) {
        loadError = api.lastError ??
            tr('Could not load shared activity for this family member.',
                'इस परिवार के सदस्य की साझा गतिविधि लोड नहीं हो सकी।');
      }
    }

    if (!mounted) return;
    setState(() {
      _lovedOnes = lovedOnes;
      _selectedUserId = selected;
      _dashboard = dashboard;
      _error = loadError;
      _loading = false;
    });
  }

  Future<void> _showPairingDialog() async {
    final controller = TextEditingController();
    final relationshipController =
        TextEditingController(text: 'Family Member');
    String? dialogError;
    var submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final code = controller.text.trim();
            if (code.isEmpty) {
              setDialogState(() => dialogError = tr(
                    'Enter the pairing code shown on your loved one\'s device.',
                    'अपने प्रियजन के डिवाइस पर दिखाया गया पेयरिंग कोड दर्ज करें।',
                  ));
              return;
            }
            setDialogState(() {
              submitting = true;
              dialogError = null;
            });
            final ok = await ApiService.instance.pairCaregiver(
              code,
              relationship: relationshipController.text.trim().isEmpty
                  ? 'Family Member'
                  : relationshipController.text.trim(),
            );
            if (!ctx.mounted) return;
            if (!ok) {
              setDialogState(() {
                submitting = false;
                dialogError = ApiService.instance.lastError ??
                    tr('The code is invalid, expired, or already used.',
                        'कोड अमान्य, समाप्त, या पहले उपयोग किया गया है।');
              });
              return;
            }
            Navigator.pop(ctx);
            if (!mounted) return;
            setState(() => _pairing = true);
            await _load();
            if (!mounted) return;
            setState(() => _pairing = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('Family member connected.',
                    'परिवार का सदस्य जुड़ गया।')),
              ),
            );
          }

          return AlertDialog(
            backgroundColor: MindoraColors.cream,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(tr('Connect a Family Member', 'परिवार का सदस्य जोड़ें'),
                style: MindoraTextStyles.titleLarge),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      'Ask your loved one to generate a one-time pairing code from Mindora Settings. Codes expire after 15 minutes.',
                      'अपने प्रियजन से Mindora सेटिंग्स में एक बार उपयोग होने वाला पेयरिंग कोड बनाने के लिए कहें। कोड 15 मिनट में समाप्त हो जाता है।',
                    ),
                    style: MindoraTextStyles.caption,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: tr('Pairing code', 'पेयरिंग कोड'),
                      hintText: 'MIND-XXXX-XXXX',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: relationshipController,
                    decoration: InputDecoration(
                      labelText: tr('Relationship', 'संबंध'),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(dialogError!,
                        style: const TextStyle(
                            color: MindoraColors.terracotta, fontSize: 13)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: Text(tr('Cancel', 'रद्द करें')),
              ),
              ElevatedButton(
                onPressed: submitting ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MindoraColors.forestGreen,
                  foregroundColor: Colors.white,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(tr('Connect', 'जोड़ें')),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    relationshipController.dispose();
  }

  Future<void> _showManageConnections() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MindoraColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Manage Connections', 'कनेक्शन प्रबंधित करें'),
                      style: MindoraTextStyles.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Removing a connection stops all future access to this family member\'s shared activity.',
                      'कनेक्शन हटाने से इस परिवार के सदस्य की साझा गतिविधि तक भविष्य की पहुँच बंद हो जाएगी।',
                    ),
                    style: MindoraTextStyles.caption,
                  ),
                  const SizedBox(height: 14),
                  if (_lovedOnes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(tr('No family members connected yet.',
                          'अभी कोई परिवार का सदस्य जुड़ा नहीं है।')),
                    )
                  else
                    ..._lovedOnes.whereType<Map>().map(
                      (row) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: MindoraColors.cardGreen,
                          child: Icon(Icons.person_rounded,
                              color: MindoraColors.forestGreen),
                        ),
                        title: Text(row['name']?.toString() ??
                            tr('Family Member', 'परिवार का सदस्य')),
                        subtitle: Text(
                            row['relationship']?.toString() ??
                                tr('Family Member', 'परिवार का सदस्य')),
                        trailing: TextButton(
                          onPressed: () async {
                            final userId = row['user_id'] as int?;
                            if (userId == null) return;
                            final ok =
                                await ApiService.instance.unpairLovedOne(userId);
                            if (!ctx.mounted) return;
                            if (!ok) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      ApiService.instance.lastError ??
                                          tr('Could not remove connection.',
                                              'कनेक्शन हटाया नहीं जा सका।')),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(ctx);
                            await _load();
                          },
                          child: Text(tr('Remove', 'हटाएँ'),
                              style: const TextStyle(
                                  color: MindoraColors.terracotta)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPairingDialog();
                      },
                      icon: const Icon(Icons.add_link_rounded),
                      label: Text(tr('Connect another family member',
                          'परिवार का एक और सदस्य जोड़ें')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MindoraColors.cream,
          appBar: AppBar(
            backgroundColor: MindoraColors.cream,
            foregroundColor: MindoraColors.forestGreen,
            elevation: 0,
            title: Text(
              tr('Caregiver Portal', 'देखभालकर्ता पोर्टल'),
              style: MindoraTextStyles.displayMedium.copyWith(fontSize: 22),
            ),
            actions: [
              IconButton(
                tooltip: tr('Connect a family member', 'परिवार का सदस्य जोड़ें'),
                icon: _pairing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link_rounded),
                onPressed: _pairing ? null : _showPairingDialog,
              ),
              IconButton(
                tooltip: tr('Manage connections', 'कनेक्शन प्रबंधित करें'),
                icon: const Icon(Icons.people_alt_outlined),
                onPressed: _showManageConnections,
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Labelled Logout stays visible above every dashboard state,
                // including loading, errors and the unpaired state.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: LogoutButton(
                      key: const Key('caregiver-logout-button'),
                      compact: true,
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(showSpinner: false),
                    color: MindoraColors.forestGreen,
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.cloud_off_rounded,
              size: 54, color: MindoraColors.textMuted),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('Try again', 'पुनः प्रयास करें')),
            ),
          ),
        ],
      );
    }

    if (_dashboard == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.family_restroom_rounded,
              size: 58, color: MindoraColors.sageGreen),
          const SizedBox(height: 14),
          Text(
            tr('No family member connected yet',
                'अभी कोई परिवार का सदस्य जुड़ा नहीं है'),
            textAlign: TextAlign.center,
            style: MindoraTextStyles.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'Ask your loved one to open Mindora Settings, generate a one-time pairing code, and share it with you. Mood is only shown when they choose to share it.',
              'अपने प्रियजन से Mindora सेटिंग्स में एक बार उपयोग होने वाला पेयरिंग कोड बनाने और आपके साथ साझा करने के लिए कहें। मनोदशा केवल तभी दिखाई देती है जब वे साझा करना चुनते हैं।',
            ),
            textAlign: TextAlign.center,
            style: MindoraTextStyles.caption,
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
              onPressed: _showPairingDialog,
              icon: const Icon(Icons.add_link_rounded),
              label: Text(tr('Connect with a pairing code',
                  'पेयरिंग कोड से जोड़ें')),
            ),
          ),
        ],
      );
    }

    final dashboard = _dashboard!;
    final user = (dashboard['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final summary =
        (dashboard['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final games = (dashboard['games_progress'] as List?) ?? const [];
    final weekly = (dashboard['weekly_trend'] as List?) ?? const [];
    final activities = (dashboard['recent_activities'] as List?) ?? const [];
    final moodShared = dashboard['mood_shared'] == true;
    final moods = (dashboard['mood_history'] as List?) ?? const [];
    final feelGood = (dashboard['feel_good_activities'] as List?) ?? const [];
    final insights = (dashboard['insights'] as List?) ?? const [];

    final today = weekly.isNotEmpty && weekly.last is Map
        ? weekly.last as Map
        : const <String, dynamic>{};
    final todayGames = _asInt(today['sessions']);
    final todayMinutes = _asDouble(today['duration_minutes']);
    final breathingCount = feelGood
        .whereType<Map>()
        .where((e) =>
            (e['activity_type']?.toString() ?? '').toLowerCase().contains(
                'breath') ||
            (e['title']?.toString() ?? '').toLowerCase().contains('breath'))
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Family Member Profile Header (Never uses the word "Patient")
        Container(
          padding: const EdgeInsets.all(18),
          decoration: mindoraGradientCard(
            colors: [
              MindoraColors.cardGreen,
              MindoraColors.cardAmber.withValues(alpha: 0.3),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: MindoraColors.forestGreen,
                child: const Icon(Icons.person_rounded,
                    size: 34, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name']?.toString() ??
                          tr('Loved One', 'प्रियजन'),
                      style:
                          MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tr("Connected profile", "संबद्ध खाता")} • '
                      '${tr("Shared with consent", "सहमति से साझा")}',
                      style: MindoraTextStyles.caption
                          .copyWith(color: MindoraColors.forestGreen),
                    ),
                    if (_lovedOnes.length > 1) ...[
                      const SizedBox(height: 8),
                      DropdownButton<int>(
                        value: _selectedUserId,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: _lovedOnes
                            .whereType<Map>()
                            .map((row) => DropdownMenuItem<int>(
                                  value: row['user_id'] as int?,
                                  child: Text(
                                    row['name']?.toString() ??
                                        tr('Family Member',
                                            'परिवार का सदस्य'),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedUserId = value);
                          _load();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MindoraColors.cardGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MindoraColors.sageGreen),
                ),
                child: Text(
                  tr('Active', 'सक्रिय'),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: MindoraColors.forestGreen),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 1. Daily Activity
        _sectionHeader(tr('Daily Activity', 'दैनिक गतिविधि'), Icons.today_rounded),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statMetricCard(
                title: tr('Games Played', 'खेले गए खेल'),
                value: '$todayGames',
                subtitle: tr('Today', 'आज'),
                icon: Icons.sports_esports_rounded,
                color: MindoraColors.cardGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statMetricCard(
                title: tr('Time Spent', 'बिताया गया समय'),
                value: _formatMinutes(todayMinutes),
                subtitle: tr('Today', 'आज'),
                icon: Icons.schedule_rounded,
                color: MindoraColors.cardAmber,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // 2. Activity Overview
        _sectionHeader(
            tr('Activity Overview', 'गतिविधि अवलोकन'), Icons.dashboard_outlined),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: mindoraCard(color: Colors.white),
          child: Column(
            children: [
              _overviewRow(
                tr('Breathing / Feel Good sessions', 'श्वास / अच्छा अनुभव सत्र'),
                '$breathingCount',
                Icons.spa_rounded,
              ),
              const Divider(height: 20),
              _overviewRow(
                tr('Average session score', 'औसत सत्र स्कोर'),
                '${_asDouble(summary['average_score']).toStringAsFixed(1)}%',
                Icons.sentiment_very_satisfied_rounded,
              ),
              const Divider(height: 20),
              _overviewRow(
                tr('Correct matches recorded', 'दर्ज सही मिलान'),
                '${_asInt(summary['total_matches'])}',
                Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 3. Game Progress
        _sectionHeader(
            tr('Game Progress', 'खेलों में प्रगति'), Icons.stairs_rounded),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: mindoraCard(color: Colors.white),
          child: games.isEmpty
              ? Text(tr('No game sessions recorded yet.',
                  'अभी कोई खेल सत्र दर्ज नहीं हुआ है।'))
              : Column(
                  children: [
                    for (var i = 0; i < games.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _gameProgressRow(
                        '${games[i]['title'] ?? games[i]['game_id'] ?? ''}',
                        tr(
                          'Level ${_asInt(games[i]['highest_level'], fallback: 1)} unlocked',
                          'स्तर ${_asInt(games[i]['highest_level'], fallback: 1)} अनलॉक',
                        ),
                        (_asInt(games[i]['highest_level'], fallback: 1) / 4)
                            .clamp(0.0, 1.0),
                      ),
                    ],
                  ],
                ),
        ),

        const SizedBox(height: 24),

        // 4. Mood History
        _sectionHeader(
            tr('Mood History', 'मनोदशा का इतिहास'), Icons.favorite_outline_rounded),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: mindoraCard(color: Colors.white),
          child: !moodShared
              ? Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: MindoraColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          'Mood sharing is turned off. Your loved one can enable it in Mindora Settings.',
                          'मनोदशा साझा करना बंद है। आपके प्रियजन इसे Mindora सेटिंग्स में चालू कर सकते हैं।',
                        ),
                        style: MindoraTextStyles.caption,
                      ),
                    ),
                  ],
                )
              : moods.isEmpty
                  ? Text(tr('No mood check-ins shared yet.',
                      'अभी कोई मनोदशा चेक-इन साझा नहीं हुआ है।'))
                  : Column(
                      children: [
                        for (var i = 0; i < moods.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _moodItem(
                            _formatDate(moods[i]['created_at']),
                            tr(
                              _moodLabel(moods[i]['mood']),
                              _moodLabelHi(moods[i]['mood']),
                            ),
                            _moodIcon(moods[i]['mood']),
                            _moodColor(moods[i]['mood']),
                          ),
                        ],
                      ],
                    ),
        ),

        const SizedBox(height: 24),

        // 5. Weekly Summary & Chart
        _sectionHeader(
            tr('Weekly Summary', 'साप्ताहिक सारांश'), Icons.bar_chart_rounded),
        const SizedBox(height: 10),
        Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: mindoraCard(color: Colors.white),
          child: weekly.isEmpty
              ? Center(
                  child: Text(tr('No weekly activity yet.',
                      'अभी कोई साप्ताहिक गतिविधि नहीं है।')))
              : BarChart(
                  BarChartData(
                    maxY: _chartMaxY(weekly),
                    barGroups: [
                      for (var i = 0; i < weekly.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _asDouble(weekly[i]['duration_minutes']),
                              color: i == weekly.length - 1
                                  ? MindoraColors.terracotta
                                  : MindoraColors.sageGreen,
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 34,
                          getTitlesWidget: (val, meta) => Text(
                            '${val.toInt()}m',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final index = val.toInt();
                            if (index < 0 || index >= weekly.length) {
                              return const SizedBox.shrink();
                            }
                            final label =
                                weekly[index]['day_name']?.toString() ?? '';
                            return Text(label,
                                style: const TextStyle(fontSize: 11));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(
                        show: true, drawVerticalLine: false),
                  ),
                ),
        ),

        const SizedBox(height: 24),

        // 6. Activity Calendar
        _sectionHeader(
            tr('Activity Calendar', 'गतिविधि कैलेंडर'), Icons.calendar_month_rounded),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: mindoraCard(color: Colors.white),
          child: weekly.isEmpty
              ? Text(tr('No activity recorded in the last 7 days.',
                  'पिछले 7 दिनों में कोई गतिविधि दर्ज नहीं हुई।'))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: weekly.map((day) {
                    final isActive = _asInt(day['sessions']) > 0;
                    return Column(
                      children: [
                        Text(
                          _shortDate(day['date']),
                          style: const TextStyle(
                              fontSize: 11, color: MindoraColors.textMuted),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isActive
                                ? MindoraColors.cardGreen
                                : MindoraColors.borderLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive
                                  ? MindoraColors.sageGreen
                                  : MindoraColors.borderMedium,
                            ),
                          ),
                          child: Icon(
                            isActive
                                ? Icons.check_rounded
                                : Icons.horizontal_rule_rounded,
                            size: 18,
                            color: isActive
                                ? MindoraColors.forestGreen
                                : MindoraColors.textMuted,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 24),

        // 7. Engagement Trends
        _sectionHeader(
            tr('Engagement Trends', 'सहभागिता का रुझान'), Icons.trending_up_rounded),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: mindoraCard(
              color: MindoraColors.cardBlue.withValues(alpha: 0.5)),
          child: Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  size: 36, color: MindoraColors.softBlue),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _engagementSummary(summary, weekly),
                  style: MindoraTextStyles.bodyMedium.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 8. Notifications
        _sectionHeader(
            tr('Notifications', 'सूचनाएं'), Icons.notifications_none_rounded),
        const SizedBox(height: 10),
        if (activities.isEmpty && moods.isEmpty && feelGood.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: mindoraCard(color: Colors.white),
            child: Text(tr('No recent notifications.',
                'हाल में कोई सूचना नहीं है।')),
          )
        else ...[
          for (var i = 0; i < activities.length && i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _notificationTile(
              title:
                  '${activities[i]['game_name'] ?? activities[i]['game_id'] ?? ''} '
                  '${tr('session', 'सत्र')}',
              subtitle: tr(
                'Level ${_asInt(activities[i]['level'], fallback: 1)} • ${_formatSeconds(_asInt(activities[i]['duration_seconds']))}',
                'स्तर ${_asInt(activities[i]['level'], fallback: 1)} • ${_formatSeconds(_asInt(activities[i]['duration_seconds']))}',
              ),
              time: _formatDate(activities[i]['created_at']),
            ),
          ],
          if (feelGood.isNotEmpty) ...[
            if (activities.isNotEmpty) const SizedBox(height: 8),
            _notificationTile(
              title: feelGood.first['title']?.toString() ??
                  tr('Feel Good activity', 'अच्छा अनुभव गतिविधि'),
              subtitle: tr('Completed a calming activity.',
                  'एक शांत गतिविधि पूरी की।'),
              time: _formatDate(feelGood.first['created_at']),
            ),
          ],
          if (moodShared && moods.isNotEmpty) ...[
            if (activities.isNotEmpty || feelGood.isNotEmpty)
              const SizedBox(height: 8),
            _notificationTile(
              title: tr('Mood check-in recorded', 'मनोदशा चेक-इन दर्ज'),
              subtitle: tr(
                _moodLabel(moods.first['mood']),
                _moodLabelHi(moods.first['mood']),
              ),
              time: _formatDate(moods.first['created_at']),
            ),
          ],
        ],

        const SizedBox(height: 24),

        // 9. Activity Insights
        _sectionHeader(
            tr('Activity Insights', 'गतिविधि अंतर्दृष्टि'), Icons.insights_rounded),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: mindoraCard(color: MindoraColors.cardAmber),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Key Observations', 'प्रमुख अवलोकन'),
                  style: MindoraTextStyles.titleMedium),
              const SizedBox(height: 8),
              if (insights.isEmpty)
                Text(tr('No observations yet.', 'अभी कोई अवलोकन नहीं है।'),
                    style: MindoraTextStyles.bodyMedium)
              else
                ...insights.whereType<Object>().map(
                      (insight) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• $insight',
                          style: MindoraTextStyles.bodyMedium
                              .copyWith(fontSize: 14, height: 1.6),
                        ),
                      ),
                    ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        // Consent Notice
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MindoraColors.borderLight),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: MindoraColors.forestGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr(
                    'Activity is visible because your loved one connected you with a one-time pairing code. Mood details appear only while mood sharing is enabled, and access can be withdrawn at any time.',
                    'गतिविधि इसलिए दिखाई दे रही है क्योंकि आपके प्रियजन ने एक बार उपयोग होने वाले पेयरिंग कोड से आपको जोड़ा है। मनोदशा का विवरण केवल तभी दिखता है जब मनोदशा साझा करना चालू हो, और पहुँच कभी भी वापस ली जा सकती है।',
                  ),
                  style: MindoraTextStyles.caption,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: TextButton.icon(
            onPressed: _showManageConnections,
            icon: const Icon(Icons.manage_accounts_rounded, size: 18),
            label: Text(tr('Manage connections', 'कनेक्शन प्रबंधित करें')),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ------------------------------------------------------------- helpers

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double _chartMaxY(List<dynamic> weekly) {
    var maxValue = 1.0;
    for (final day in weekly.whereType<Map>()) {
      final value = _asDouble(day['duration_minutes']);
      if (value > maxValue) maxValue = value;
    }
    return (maxValue * 1.25).ceilToDouble();
  }

  String _formatMinutes(double minutes) {
    if (minutes <= 0) return '0m';
    if (minutes < 1) return '<1m';
    return '${minutes.round()}m';
  }

  String _formatSeconds(int seconds) {
    if (seconds <= 0) return '—';
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return rest == 0 ? '${minutes}m' : '${minutes}m ${rest}s';
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString();
    var normalized = text.replaceFirst(' ', 'T');
    final hasZone = normalized.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(normalized);
    if (!hasZone) normalized = '${normalized}Z';
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return text;
    final local = parsed.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(day).inDays;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (difference == 0) return '${tr('Today', 'आज')} $time';
    if (difference == 1) return '${tr('Yesterday', 'कल')} $time';
    return '${local.day}/${local.month}/${local.year} $time';
  }

  String _shortDate(dynamic raw) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '';
    return '${parsed.day}/${parsed.month}';
  }

  String _engagementSummary(
      Map<String, dynamic> summary, List<dynamic> weekly) {
    final totalGames = _asInt(summary['total_games_played']);
    final minutes = _asDouble(summary['total_duration_minutes']);
    final activeDays = weekly
        .whereType<Map>()
        .where((day) => _asInt(day['sessions']) > 0)
        .length;
    if (totalGames == 0) {
      return tr(
        'No sessions yet. Gentle daily play will build a calm activity pattern here.',
        'अभी कोई सत्र नहीं हुआ। नियमित हल्का खेल यहाँ एक शांत गतिविधि पैटर्न बनाएगा।',
      );
    }
    return tr(
      '$totalGames sessions recorded across $activeDays active day(s) this week, with ${minutes.toStringAsFixed(1)} total minutes shared. Pacing is shown without comparing speed.',
      'इस सप्ताह $activeDays सक्रिय दिनों में $totalGames सत्र दर्ज हुए, कुल ${minutes.toStringAsFixed(1)} मिनट साझा किए गए। गति की तुलना नहीं की जाती।',
    );
  }

  String _moodLabel(dynamic mood) {
    switch (mood?.toString().toLowerCase()) {
      case 'happy':
      case 'great':
        return 'Happy';
      case 'calm':
      case 'peaceful':
        return 'Calm';
      case 'okay':
      case 'neutral':
        return 'Okay';
      case 'sad':
      case 'low':
        return 'Low';
      case 'anxious':
      case 'stressed':
        return 'Anxious';
      default:
        return mood?.toString() ?? 'Mood check-in';
    }
  }

  String _moodLabelHi(dynamic mood) {
    switch (mood?.toString().toLowerCase()) {
      case 'happy':
      case 'great':
        return 'आनंदित';
      case 'calm':
      case 'peaceful':
        return 'शांत';
      case 'okay':
      case 'neutral':
        return 'ठीक';
      case 'sad':
      case 'low':
        return 'उदास';
      case 'anxious':
      case 'stressed':
        return 'चिंतित';
      default:
        return mood?.toString() ?? 'मनोदशा';
    }
  }

  IconData _moodIcon(dynamic mood) {
    switch (mood?.toString().toLowerCase()) {
      case 'happy':
      case 'great':
        return Icons.sentiment_very_satisfied_rounded;
      case 'calm':
      case 'peaceful':
        return Icons.spa_rounded;
      case 'sad':
      case 'low':
        return Icons.sentiment_dissatisfied_rounded;
      case 'anxious':
      case 'stressed':
        return Icons.sentiment_neutral_rounded;
      default:
        return Icons.sentiment_satisfied_alt_rounded;
    }
  }

  Color _moodColor(dynamic mood) {
    switch (mood?.toString().toLowerCase()) {
      case 'happy':
      case 'great':
        return MindoraColors.warmAmber;
      case 'calm':
      case 'peaceful':
        return MindoraColors.sageGreen;
      case 'sad':
      case 'low':
      case 'anxious':
      case 'stressed':
        return MindoraColors.terracotta;
      default:
        return MindoraColors.softBlue;
    }
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: MindoraColors.sageGreen, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: MindoraTextStyles.titleLarge.copyWith(fontSize: 18),
        ),
      ],
    );
  }

  Widget _statMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: mindoraCard(color: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MindoraColors.forestGreen, size: 26),
          const SizedBox(height: 10),
          Text(value,
              style: MindoraTextStyles.displayMedium.copyWith(fontSize: 26)),
          const SizedBox(height: 2),
          Text(title,
              style: MindoraTextStyles.titleMedium.copyWith(fontSize: 14)),
          Text(subtitle, style: MindoraTextStyles.caption),
        ],
      ),
    );
  }

  Widget _overviewRow(String title, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 22, color: MindoraColors.sageGreen),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: MindoraTextStyles.bodyMedium)),
        Text(value,
            style: MindoraTextStyles.titleMedium.copyWith(fontSize: 14)),
      ],
    );
  }

  Widget _gameProgressRow(String game, String status, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(game,
                style: MindoraTextStyles.titleMedium.copyWith(fontSize: 15)),
            Text(status, style: MindoraTextStyles.caption),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: MindoraColors.borderLight,
          color: MindoraColors.sageGreen,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _moodItem(String time, String mood, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
            child: Text(mood,
                style: MindoraTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600))),
        Text(time, style: MindoraTextStyles.caption),
      ],
    );
  }

  Widget _notificationTile({
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: mindoraCard(color: Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 10, color: MindoraColors.sageGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        MindoraTextStyles.titleMedium.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: MindoraTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(time, style: MindoraTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
