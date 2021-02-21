//
//  EventViewModel.swift
//  Calendr
//
//  Created by Paker on 23/01/21.
//

import RxCocoa
import RxSwift

class EventViewModel {

    let title: String
    let duration: String
    let color: CGColor
    let isPending: Bool

    let isLineVisible: Observable<Bool>
    let backgroundColor: Observable<CGColor>
    let isFaded: Observable<Bool>
    let isHidden: Observable<Bool>
    let progress: Observable<CGFloat?>

    init(
        event: EventModel,
        dateProvider: DateProviding,
        settings: SettingsViewModel,
        scheduler: SchedulerType = MainScheduler.instance
    ) {

        title = event.title
        color = event.calendar.color
        isPending = event.isPending

        // fix range ending at 00:00 of the next day
        let fixedEnd = dateProvider.calendar.date(byAdding: .second, value: -1, to: event.end)!
        let isSingleDay = dateProvider.calendar.isDate(event.start, inSameDayAs: fixedEnd)
        let isSameMonth = dateProvider.calendar.isDate(event.start, equalTo: fixedEnd, toGranularity: .month)
        let startsMidnight = dateProvider.calendar.date(event.start, matchesComponents: .init(hour: 0, minute: 0))
        let endsMidnight = dateProvider.calendar.date(event.end, matchesComponents: .init(hour: 0, minute: 0))
        let showTime = !(startsMidnight && endsMidnight)

        if event.isAllDay {

            duration = ""

        } else if isSingleDay {

            let formatter = DateIntervalFormatter()
            formatter.dateTemplate = "jm"
            formatter.locale = dateProvider.calendar.locale!

            let end = endsMidnight ? dateProvider.calendar.startOfDay(for: event.start) : event.end

            duration = formatter.string(from: event.start, to: end)

        } else if !showTime {

            let formatter = DateIntervalFormatter()
            formatter.dateTemplate = isSameMonth ? "ddMMMM" : "ddMMM"
            formatter.locale = dateProvider.calendar.locale!

            duration = formatter.string(from: event.start, to: fixedEnd)

        } else {

            let formatter = DateFormatter(
                template: "ddMMyyyyHm",
                locale: dateProvider.calendar.locale!
            )
            let start = formatter.string(from: event.start)
            let end = formatter.string(from: showTime ? event.end : fixedEnd)

            duration = "\(start)\n\(end)"
        }

        let total = dateProvider.calendar
            .dateComponents([.second], from: event.start, to: event.end)
            .second ?? 0

        let clock = Observable<Int>.interval(.seconds(1), scheduler: scheduler)
            .toVoid()
            .startWith(())
            .share(replay: 1)

        progress = total <= 0 || !isSingleDay || event.isAllDay ? .just(nil) : clock.map {
            guard
                dateProvider.calendar.isDate(event.end, greaterThanOrEqualTo: dateProvider.now, granularity: .second),
                let ellapsed = dateProvider.calendar.dateComponents(
                    [.second], from: event.start, to: dateProvider.now
                ).second, ellapsed >= 0
            else { return nil }

            return CGFloat(ellapsed) / CGFloat(total)
        }
        .distinctUntilChanged()
        .share(replay: 1)

        let isPast = event.isAllDay ? .just(false) : clock.map {
            return dateProvider.calendar.isDate(event.end, inSameDayAs: dateProvider.now)
                && dateProvider.calendar.isDate(event.end, lessThan: dateProvider.now, granularity: .second)
        }
        .distinctUntilChanged()
        .share(replay: 1)

        isFaded = Observable.combineLatest(isPast, settings.showPastEvents)
            .map { $0 && $1 }
            .distinctUntilChanged()
            .share(replay: 1)

        isHidden = Observable.combineLatest(isPast, settings.showPastEvents)
            .map { $0 && !$1 }
            .distinctUntilChanged()
            .share(replay: 1)

        isLineVisible = progress.map { $0 != nil }.distinctUntilChanged()

        let progressBackgroundColor = color.copy(alpha: 0.1)!

        backgroundColor = isLineVisible.map { $0 ? progressBackgroundColor : .clear }
    }
}
