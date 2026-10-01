tell application "Finder"
    -- An already empty Trash is a successful no-op.
    if (count of items of trash) is 0 then return true
    set previousWarnState to warns before emptying of trash
    try
        set warns before emptying of trash to false
        empty trash
        set warns before emptying of trash to previousWarnState
        return true
    on error errMessage number errNumber
        try
            set warns before emptying of trash to previousWarnState
        end try
        -- Finder cancellation is not an application failure. Do not retry deletion.
        if errNumber is -128 then return false
        error errMessage number errNumber
    end try
end tell
