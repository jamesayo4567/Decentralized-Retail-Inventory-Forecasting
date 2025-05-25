;; Demand Prediction Contract
;; Forecasts future inventory needs based on historical data

(define-constant ERR_INSUFFICIENT_DATA (err u300))
(define-constant ERR_INVALID_PERIOD (err u301))
(define-constant ERR_UNAUTHORIZED (err u302))

;; Data structures
(define-map demand-forecasts { retailer: principal, product-id: uint, forecast-period: uint } {
    predicted-demand: uint,
    confidence-level: uint,
    algorithm-used: (string-ascii 20),
    created-at: uint,
    factors: (list 5 uint)
})

(define-map seasonal-patterns { product-id: uint, season: (string-ascii 10) } {
    demand-multiplier: uint,
    historical-average: uint,
    volatility-score: uint
})

;; Public functions
(define-public (generate-forecast (retailer principal) (product-id uint) (forecast-period uint) (historical-data (list 12 uint)))
    (let ((base-demand (calculate-base-demand historical-data))
          (seasonal-factor (get-seasonal-factor product-id "current"))
          (trend-factor (calculate-trend historical-data))
          (predicted-demand (calculate-predicted-demand base-demand seasonal-factor trend-factor)))

        (asserts! (> (len historical-data) u2) ERR_INSUFFICIENT_DATA)
        (asserts! (> forecast-period (/ block-height u144)) ERR_INVALID_PERIOD)

        (map-set demand-forecasts { retailer: retailer, product-id: product-id, forecast-period: forecast-period } {
            predicted-demand: predicted-demand,
            confidence-level: (calculate-confidence historical-data),
            algorithm-used: "simple-trend",
            created-at: block-height,
            factors: (list base-demand seasonal-factor trend-factor u0 u0)
        })
        (ok predicted-demand)
    )
)

(define-public (update-seasonal-pattern (product-id uint) (season (string-ascii 10)) (multiplier uint) (average uint))
    (begin
        (map-set seasonal-patterns { product-id: product-id, season: season } {
            demand-multiplier: multiplier,
            historical-average: average,
            volatility-score: u50
        })
        (ok true)
    )
)

;; Private calculation functions
(define-private (calculate-base-demand (data (list 12 uint)))
    (/ (fold + data u0) (len data))
)

(define-private (get-seasonal-factor (product-id uint) (season (string-ascii 10)))
    (match (map-get? seasonal-patterns { product-id: product-id, season: season })
        pattern (get demand-multiplier pattern)
        u100 ;; Default multiplier of 1.0 (represented as 100)
    )
)

(define-private (calculate-trend (data (list 12 uint)))
    (let ((data-length (len data)))
        (if (> data-length u1)
            (let ((recent (unwrap-panic (element-at data (- data-length u1))))
                  (older (unwrap-panic (element-at data (- data-length u2)))))
                (if (> recent older)
                    u110 ;; Upward trend
                    u90  ;; Downward trend
                )
            )
            u100 ;; No trend
        )
    )
)

(define-private (calculate-predicted-demand (base uint) (seasonal uint) (trend uint))
    (/ (* (* base seasonal) trend) u10000)
)

(define-private (calculate-confidence (data (list 12 uint)))
    (let ((data-length (len data)))
        (if (> data-length u6)
            u80 ;; High confidence
            u60 ;; Medium confidence
        )
    )
)

;; Read-only functions
(define-read-only (get-forecast (retailer principal) (product-id uint) (forecast-period uint))
    (map-get? demand-forecasts { retailer: retailer, product-id: product-id, forecast-period: forecast-period })
)

(define-read-only (get-seasonal-pattern (product-id uint) (season (string-ascii 10)))
    (map-get? seasonal-patterns { product-id: product-id, season: season })
)

(define-read-only (get-multiple-forecasts (retailer principal) (product-ids (list 10 uint)) (forecast-period uint))
    (map get-single-forecast product-ids)
)

(define-private (get-single-forecast (product-id uint))
    (map-get? demand-forecasts { retailer: tx-sender, product-id: product-id, forecast-period: u1 })
)
