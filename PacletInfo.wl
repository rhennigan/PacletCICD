PacletObject[ <|
    "Name"             -> "Wolfram/PacletCICD",
    "Description"      -> "Continuous integration and deployment for Wolfram Language paclets",
    "Creator"          -> "Richard Hennigan <richardh@wolfram.com>",
    "URL"              -> "https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/PacletCICD",
    "SourceControlURL" -> "https://github.com/rhennigan/PacletCICD",
    "License"          -> "MIT",
    "PublisherID"      -> "Wolfram",
    "Version"          -> "0.29.3",
    "WolframVersion"   -> "13.0+",
    "ReleaseID"        -> "$RELEASE_ID$",
    "ReleaseDate"      -> "$RELEASE_DATE$",
    "ReleaseURL"       -> "$RELEASE_URL$",
    "ActionURL"        -> "$ACTION_URL$",
    "Icon"             -> "Images/PacletIcon.png",
    "Dependencies"     -> {
        "DefinitionNotebookClient" -> ">=1.10.0",
        "PacletResource"           -> ">=0.11.0",
        "ResourceSystemClient"     -> ">=1.24.0"
    },
    "Extensions"       -> {
        {
            "Kernel",
            "Root"    -> "Kernel",
            "Context" -> { "Wolfram`PacletCICD`" },
            "Symbols" -> {
                "Wolfram`PacletCICD`$ExamplesLocation",
                "Wolfram`PacletCICD`AnnotateTestIDs",
                "Wolfram`PacletCICD`BuildPaclet",
                "Wolfram`PacletCICD`CheckDependencies",
                "Wolfram`PacletCICD`CheckPaclet",
                "Wolfram`PacletCICD`CreatePublisherToken",
                "Wolfram`PacletCICD`DeployPaclet",
                "Wolfram`PacletCICD`ExampleDirectory",
                "Wolfram`PacletCICD`GitHubPacletInstall",
                "Wolfram`PacletCICD`GitHubSecret",
                "Wolfram`PacletCICD`PacletCICD",
                "Wolfram`PacletCICD`PublisherTokenObject",
                "Wolfram`PacletCICD`SubmitPaclet",
                "Wolfram`PacletCICD`TestPaclet",
                "Wolfram`PacletCICD`Workflow",
                "Wolfram`PacletCICD`WorkflowEvaluate",
                "Wolfram`PacletCICD`WorkflowExport",
                "Wolfram`PacletCICD`WorkflowJob",
                "Wolfram`PacletCICD`WorkflowJobQ",
                "Wolfram`PacletCICD`WorkflowQ",
                "Wolfram`PacletCICD`WorkflowStep",
                "Wolfram`PacletCICD`WorkflowStepQ",
                "Wolfram`PacletCICD`WorkflowValue"
            }
        },
        {
            "Documentation",
            "Root"     -> "Documentation",
            "Language" -> "English"
        },
        {
            "Asset",
            "Assets" -> {
                { "License"  , "./LICENSE"   },
                { "ReadMe"   , "./README.md" },
                { "Images"   , "./Images"    },
                { "Examples" , "./Examples"  },
                { "Resources", "./Resources" }
            }
        }
    }
|> ]
