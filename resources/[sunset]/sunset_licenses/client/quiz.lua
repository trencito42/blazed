local quizOpen = false

local function closeQuiz()
    if not quizOpen then return end
    quizOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

function OpenTheoryQuiz(licenseType, theory)
    if quizOpen then return end
    quizOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'show',
        licenseType = licenseType,
        title = theory.title,
        intro = theory.intro,
        questions = theory.questions,
    })
end

RegisterNUICallback('licenseQuizClose', function(_, cb)
    closeQuiz()
    Sunset.AwaitCallback('sunset:license:abortTest')
    cb('ok')
end)

RegisterNUICallback('licenseQuizSubmit', function(data, cb)
    local licenseType = data and data.licenseType
    local answers = data and data.answers
    closeQuiz()
    local result, err = Sunset.AwaitCallback('sunset:license:submitTheory', licenseType, answers)
    if not result then
        exports.sunset_ui:Notify(err or 'Theory exam failed.', 'error', 8000)
        cb('ok')
        return
    end
    exports.sunset_ui:Notify('Theory passed — starting practical test.', 'success', 7000)
    TriggerEvent('sunset:licenses:beginPractical', licenseType, result)
    cb('ok')
end)

exports('OpenTheoryQuiz', OpenTheoryQuiz)
