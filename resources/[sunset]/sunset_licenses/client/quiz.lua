local quizOpen = false

local function closeQuiz()
    if not quizOpen then return end
    quizOpen = false
    exports.sunset_ui:SetFocus(false, false)
    exports.sunset_ui:Send('licenseQuizHide', {})
end

function OpenTheoryQuiz(licenseType, theory)
    if quizOpen then return end
    quizOpen = true
    exports.sunset_ui:Send('licenseQuizShow', {
        licenseType = licenseType,
        title = theory.title,
        intro = theory.intro,
        questions = theory.questions,
        examFee = theory.examFee,
        theoryTimeSec = theory.theoryTimeSec,
        deadlineAt = theory.deadlineAt,
    })
    exports.sunset_ui:SetFocus(true, true)
end

AddEventHandler('sunset:nui:licenseQuizClose', function()
    closeQuiz()
    Sunset.AwaitCallback('sunset:license:abortTest')
end)

AddEventHandler('sunset:nui:licenseQuizSubmit', function(data)
    local licenseType = data and data.licenseType
    local answers = data and data.answers
    closeQuiz()
    local result, err = Sunset.AwaitCallback('sunset:license:submitTheory', licenseType, answers)
    if not result then
        exports.sunset_ui:Notify(err or 'Theory exam failed.', 'error', 8000)
        TriggerEvent('sunset:licenses:testAbort')
        return
    end
    TriggerEvent('sunset:licenses:beginPractical', licenseType, result)
end)

exports('OpenTheoryQuiz', OpenTheoryQuiz)
exports('CloseTheoryQuiz', closeQuiz)
