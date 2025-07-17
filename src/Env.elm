module Env exposing (..)

-- The Env.elm file is for per-environment configuration.
-- See https://dashboard.lamdera.app/docs/environment for more info.


dummyConfigItem =
    ""


modelKey =
    "1234567890"


slackApiToken =
    "1234567890"


slackChannel =
    "#test"


logSize =
    "2000"


stillTesting =
    "1"


auth0AppClientId : String
auth0AppClientId =
    "qqkzut4gKyC6Y2lB3nlPsOBwnLmTQxfx"


auth0AppClientSecret : String
auth0AppClientSecret =
    "-2bRUV-1JXwO9sqCuTdKziBYG1Rn83bfRvB9LPBqsp5yFcVClx19G-6dI0XtDmEU"


auth0AppTenant : String
auth0AppTenant =
    "dev-ioeftjgqbnfyd4lp.us.auth0.com"


sysAdminEmail : String
sysAdminEmail =
    "schalk.dormehl@gmail.com"


openAiApiKey : String
openAiApiKey =
    ""


openRouterApiKey : String
openRouterApiKey =
    "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"


moralisApiKey : String
moralisApiKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6ImViNDEyNTU5LWUyZWYtNDg2Ny04ZThmLTFlMDlmODYwMzFmMiIsIm9yZ0lkIjoiNDU5NzEyIiwidXNlcklkIjoiNDcyOTYyIiwidHlwZUlkIjoiMjE5NjViMjAtOWE0YS00MTFjLWFmMzAtNThlYTRjMGFiNDNjIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3NTI3MDA4MDIsImV4cCI6NDkwODQ2MDgwMn0.ua5Fd72vuUm0tg742h9x5N8JMSfEHmAqduH335iIAkg"


alchemyApiKey : String
alchemyApiKey =
    "UF9iXc8OyKFMJHfd5p40k"


goldRushApiKey : String
goldRushApiKey =
    "cqt_rQjTc7CCf3m6wVkBcp68kh98BrwJ"


shroomTokenAddress : String
shroomTokenAddress =
    "0xAD3eB8058e9E0ad547e2aF549388Df451b00D8BD"


type Mode
    = Development
    | Production


mode =
    Development
