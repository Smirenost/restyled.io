module Restyled.TimeRange
    ( TimeRange
    , timeRangeBefore
    , timeRangeFromMinutesAgo
    , timeRangeFromHoursAgo
    , rawSqlWithTimeRange
    , withinTimeRange
    , timeRangeFilters
    )
where

import Restyled.Prelude

import qualified Database.Esqueleto as E
import Database.Persist.Sql (RawSql, rawSql)

data TimeRange = TimeRange
    { tmFrom :: UTCTime
    , tmTo :: UTCTime
    }

instance ToJSON TimeRange where
    toJSON TimeRange {..} = object ["from" .= tmFrom, "to" .= tmTo]

timeRangeBefore :: TimeRange -> TimeRange
timeRangeBefore TimeRange {..} = TimeRange
    { tmFrom = addUTCTime (negate diff) tmFrom
    , tmTo = tmFrom
    }
    where diff = diffUTCTime tmTo tmFrom

timeRangeFromMinutesAgo :: MonadIO m => Int -> m TimeRange
timeRangeFromMinutesAgo minutes = do
    now <- getCurrentTime
    pure $ timeRangeToVia now $ subtractMinutes minutes

timeRangeFromHoursAgo :: MonadIO m => Int -> m TimeRange
timeRangeFromHoursAgo = timeRangeFromMinutesAgo . (* 60)

timeRangeToVia :: UTCTime -> (UTCTime -> UTCTime) -> TimeRange
timeRangeToVia tmTo f = let tmFrom = f tmTo in TimeRange { .. }

subtractMinutes :: Int -> UTCTime -> UTCTime
subtractMinutes minutes = addUTCTime $ fromIntegral $ negate $ minutes * 60

rawSqlWithTimeRange
    :: (RawSql a, MonadIO m) => TimeRange -> Text -> SqlPersistT m [a]
rawSqlWithTimeRange TimeRange {..} =
    flip rawSql [PersistUTCTime tmFrom, PersistUTCTime tmTo]

withinTimeRange
    :: E.SqlExpr (E.Value UTCTime) -> TimeRange -> E.SqlExpr (E.Value Bool)
withinTimeRange field TimeRange {..} =
    field E.>=. E.val tmFrom E.&&. field E.<=. E.val tmTo

infix 4 `withinTimeRange`

timeRangeFilters :: EntityField e UTCTime -> TimeRange -> [Filter e]
timeRangeFilters field TimeRange {..} = [field >=. tmFrom, field <=. tmTo]
