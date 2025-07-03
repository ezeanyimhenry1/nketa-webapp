import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:the_igbo_bible/widgets/custom_container.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:the_igbo_bible/services/event_service.dart';
import 'package:the_igbo_bible/models/igbo_event.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late List<DateTime?> _singleDatePickerValueWithDefaultValue;

  // Igbo market days cycle
  final List<String> marketDays = ['Eke', 'Orie', 'Afo', 'Nkwo'];

  final DateTime referenceDate = DateTime(2025, 6, 22);
  final int referenceDayIndex = 0; // 0=Eke, 1=Orie, 2=Afo, 3=Nkwo

  List<IgboEvent> _events = [];
  bool _eventsLoading = true;

  @override
  void initState() {
    super.initState();
    _singleDatePickerValueWithDefaultValue = [_getNigerianDateTime()];
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await EventService().loadEvents();
    setState(() {
      _events = events;
      _eventsLoading = false;
    });
  }

  // Helper method to get current Nigerian time
  static DateTime _getNigerianDateTime() {
    final lagosLocation = tz.getLocation('Africa/Lagos');
    final now = tz.TZDateTime.now(lagosLocation);
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  // Calculate the market day for a given date
  String getMarketDay(DateTime date) {
    final daysDifference = date.difference(referenceDate).inDays;
    final marketDayIndex = (referenceDayIndex + daysDifference) % 4;
    return marketDays[marketDayIndex];
  }

  // Get the current market day
  String getCurrentMarketDay() {
    final nigerianDate = _getNigerianDateTime();
    return getMarketDay(nigerianDate);
  }

  // Helper method to format Nigerian date
  String _getFormattedNigerianDate() {
    final nigerianDate = _getNigerianDateTime();
    return DateFormat('EEEE, MMMM d').format(nigerianDate);
  }

  // Get color scheme for each market day
  Map<String, dynamic> getMarketDayColors(String marketDay) {
    switch (marketDay) {
      case 'Eke':
        return {
          'bgColor': const Color.fromARGB(92, 76, 175, 80),
          'borderColor': const Color.fromARGB(255, 27, 94, 32),
          'textColor': const Color.fromARGB(255, 27, 94, 32),
        };
      case 'Orie':
        return {
          'bgColor': const Color.fromARGB(92, 255, 153, 0),
          'borderColor': const Color.fromARGB(255, 132, 34, 1),
          'textColor': const Color.fromARGB(255, 132, 34, 1),
        };
      case 'Afo':
        return {
          'bgColor': const Color.fromARGB(92, 33, 150, 243),
          'borderColor': const Color.fromARGB(255, 13, 71, 161),
          'textColor': const Color.fromARGB(255, 13, 71, 161),
        };
      case 'Nkwo':
        return {
          'bgColor': const Color.fromARGB(92, 156, 39, 176),
          'borderColor': const Color.fromARGB(255, 74, 20, 140),
          'textColor': const Color.fromARGB(255, 74, 20, 140),
        };
      default:
        return {
          'bgColor': const Color.fromARGB(92, 158, 158, 158),
          'borderColor': const Color.fromARGB(255, 97, 97, 97),
          'textColor': const Color.fromARGB(255, 97, 97, 97),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final currentMarketDay = getCurrentMarketDay();
    final currentColors = getMarketDayColors(currentMarketDay);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.w),
        child: Column(
          children: [
            SizedBox(height: AppSpacing.sm.h),
            CustomContainer(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Market Day", style: textTheme.titleMedium),
                      Text(
                        _getFormattedNigerianDate(),
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  Center(
                    child: Container(
                      width: 100.w,
                      padding: EdgeInsets.all(AppSpacing.sm.w),
                      decoration: BoxDecoration(
                        color: currentColors['bgColor'],
                        borderRadius: BorderRadius.circular(50.r),
                        border: Border.all(
                          color: currentColors['borderColor'],
                          width: 2.w,
                        ),
                      ),
                      child: Text(
                        textAlign: TextAlign.center,
                        currentMarketDay,
                        style: textTheme.headlineMedium?.copyWith(
                          color: currentColors['textColor'],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:
                        marketDays.map((marketDay) {
                          final isCurrentDay = marketDay == currentMarketDay;
                          final colors = getMarketDayColors(marketDay);
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: marketDay != marketDays.last ? 6.w : 0,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.sm.h,
                                horizontal: AppSpacing.xs.w,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isCurrentDay
                                        ? colors['borderColor']
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(
                                  isCurrentDay ? 50.r : 20.r,
                                ),
                              ),
                              child: Text(
                                textAlign: TextAlign.center,
                                marketDay,
                                style: textTheme.bodyMedium?.copyWith(
                                  color:
                                      isCurrentDay
                                          ? Colors.white
                                          : Colors.black,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            CustomContainer(
              content: _buildSingleDatePickerWithValue(textTheme),
            ),
            SizedBox(height: AppSpacing.md.h),
            CustomContainer(content: _buildEventsForSelectedDate()),
            SizedBox(height: AppSpacing.lg.h),
            CustomContainer(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Market Days',
                    textAlign: TextAlign.left,
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    'The traditional Igbo calendar follows a 4-day market cycle: Eke, Orie, Afo, and Nkwo. Each day has cultural significance and determines market activities across Igbo communities.',
                    style: textTheme.bodySmall,
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    'Current cycle: ${getCurrentMarketDay()} → ${getMarketDay(_getNigerianDateTime().add(Duration(days: 1)))} → ${getMarketDay(_getNigerianDateTime().add(Duration(days: 2)))} → ${getMarketDay(_getNigerianDateTime().add(Duration(days: 3)))}',
                    style: textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDatePickerWithValue(TextTheme textTheme) {
    final nigerianNow = _getNigerianDateTime();

    final config = CalendarDatePicker2Config(
      selectedDayHighlightColor: Colors.transparent,
      selectedYearTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      selectedMonthTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      disabledMonthTextStyle: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
      ),
      monthTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      selectedDayTextStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      weekdayLabels: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      weekdayLabelTextStyle: const TextStyle(
        color: Colors.black38,
        fontWeight: FontWeight.bold,
      ),
      firstDayOfWeek: 1,
      controlsHeight: 50,
      dayMaxWidth: 25,
      animateToDisplayedMonthDate: true,
      controlsTextStyle: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
      dayTextStyle: const TextStyle(
        color: Colors.grey,
        fontWeight: FontWeight.bold,
      ),
      disabledDayTextStyle: TextStyle(color: Colors.black),
      centerAlignModePicker: true,
      useAbbrLabelForMonthModePicker: true,
      modePickersGap: 0,
      modePickerTextHandler: ({required monthDate, isMonthPicker}) {
        if (isMonthPicker ?? false) {
          return getLocaleShortMonthFormat(
            const Locale('en'),
          ).format(monthDate);
        }
        return null;
      },
      firstDate: DateTime(
        nigerianNow.year - 2,
        nigerianNow.month - 1,
        nigerianNow.day - 5,
      ),
      lastDate: DateTime(
        nigerianNow.year + 3,
        nigerianNow.month + 2,
        nigerianNow.day + 10,
      ),
      selectableDayPredicate: (day) => true,
      currentDate: nigerianNow,
      dayBuilder: ({
        required date,
        textStyle,
        decoration,
        isSelected,
        isDisabled,
        isToday,
      }) {
        final nigerianToday = _getNigerianDateTime();
        final isNigerianToday =
            date.year == nigerianToday.year &&
            date.month == nigerianToday.month &&
            date.day == nigerianToday.day;
        final hasEvent = _events.any(
          (event) =>
              (event.recurring &&
                  event.date.month == date.month &&
                  event.date.day == date.day) ||
              (!event.recurring &&
                  event.date.year == date.year &&
                  event.date.month == date.month &&
                  event.date.day == date.day),
        );
        Widget dayText = Text('${date.day}', style: textStyle);
        if (hasEvent) {
          dayText = Stack(
            alignment: Alignment.center,
            children: [
              dayText,
              Positioned(
                bottom: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          );
        }
        if (isNigerianToday) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Center(
              child: Text(
                '${date.day}',
                style: textStyle?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
        return dayText;
      },
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.grey.withAlpha(50)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        width: 375,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            SizedBox(
              width: 270,
              child: CalendarDatePicker2(
                displayedMonthDate:
                    _singleDatePickerValueWithDefaultValue.first,
                config: config,
                value: _singleDatePickerValueWithDefaultValue,
                onValueChanged:
                    (dates) => setState(
                      () => _singleDatePickerValueWithDefaultValue = dates,
                    ),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsForSelectedDate() {
    if (_eventsLoading) {
      return const Center(child: ShimmerLoader(height: 32, width: 32));
    }
    final selectedDate = _singleDatePickerValueWithDefaultValue.first;
    if (selectedDate == null) return const SizedBox();
    final normalizedSelected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final eventsForDay =
        _events.where((event) {
          if (event.recurring) {
            return event.date.month == normalizedSelected.month &&
                event.date.day == normalizedSelected.day;
          } else {
            final normalizedEvent = DateTime(
              event.date.year,
              event.date.month,
              event.date.day,
            );
            return normalizedEvent == normalizedSelected;
          }
        }).toList();

    if (eventsForDay.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('No Igbo events on this day.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Events on this day:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...eventsForDay.map(
          (event) => Card(
            color: Colors.green[50],
            child: ListTile(
              leading:
                  event.imageUrl != null
                      ? Image.asset(event.imageUrl!, width: 40, height: 40)
                      : null,
              title: Text(event.name),
              subtitle: Text('${event.description}\n${event.location ?? ''}'),
            ),
          ),
        ),
      ],
    );
  }
}
