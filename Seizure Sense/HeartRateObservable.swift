//
//  HeartRateObservable.swift
//  Maren_View_3
//
//  Created by Maren McCrossan on 4/8/26.
//

import Combine
import Foundation

class HeartRateObservable: ObservableObject {
    @Published var heartRate: Double = 0
}
