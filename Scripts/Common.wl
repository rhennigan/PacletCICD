BeginPackage[ "Wolfram`PacletCICD`Scripts`" ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

Wolfram`PacletCICD`$Debug = True;

Off[ DocumentationBuild`Utils`Localized::nokey ];
Off[ PacletInstall::samevers ];

PacletInstall[ "https://www.wolframcloud.com/obj/rhennigan/Paclets/DefinitionNotebookClient-1.14.0.paclet" ];
Needs[ "DefinitionNotebookClient`" -> None ];
Print @ Definition @ DefinitionNotebookClient`UpdateDefinitionNotebook`PackagePrivate`pmHack;

(* ::**********************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
$messageHistoryLength = 10;
$messageNumber        = 0;
$messageHistory       = <| |>;
$stackHistory         = <| |>;

Internal`AddHandler[ "Message", messageHandler ];

$testingHeads = HoldPattern @ Alternatives[
    TestReport,
    VerificationTest,
    Testing`Private`extractUnevaluated
];

$testStack = With[ { h = $testingHeads }, HoldForm[ h[ ___ ] ] ];

messageHandler[ Hold[ msg_, True ] ] /; $messageNumber < $messageHistoryLength :=
    StackInhibit @ Module[ { stack, keys, limit, drop },
        stack = Stack[ _ ];
        If[ MemberQ[ stack, $testStack ], Throw[ Null, $tag ] ];

        $messageNumber += 1;
        $messageHistory[ $messageNumber ] = HoldForm @ msg;
        $stackHistory[   $messageNumber ] = stack;

        keys  = Union[ Keys @ $messageHistory, Keys @ $stackHistory ];
        limit = $messageNumber - $messageHistoryLength;
        drop  = Select[ keys, ! TrueQ[ # > limit ] & ];

        KeyDropFrom[ $messageHistory, drop ];
        KeyDropFrom[ $stackHistory  , drop ];

        messagePrint @ msg;
    ] ~Catch~ $tag;


messagePrint // Attributes = { HoldFirst };

messagePrint[ Message[ msg_, args___ ] ] :=
    messagePrint[ msg, args ];

messagePrint[ msg_MessageName, args___ ] :=
    Print[ "::warning::",
           ToString @ Unevaluated @ msg <> ": " <> messageString[ msg, args ]
    ];


messageString[ template_String, args___ ] :=
    ToString[ StringForm[ template, Sequence @@ Short /@ { args } ],
              OutputForm,
              PageWidth -> 80
    ];

messageString[ HoldPattern @ MessageName[ f_, tag_ ], args___ ] :=
    With[ { template = MessageName[ General, tag ] },
        messageString[ template, args ] /; StringQ @ template
    ];

messageString[ ___ ] := "-- Message text not found --";

(* ::**********************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*gitCommand*)
gitCommand[ { cmd__String }, dir_ ] :=
    Enclose @ Module[ { res },
        res = RunProcess[ { "git", cmd }, ProcessDirectory -> dir ];
        ConfirmAssert[ res[ "ExitCode" ] === 0 ];
        StringTrim @ ConfirmBy[ res[ "StandardOutput" ], StringQ ]
    ];

gitCommand[ cmd_String, dir_ ] := gitCommand[ { cmd }, dir ];

gitCommand[ cmd_ ] := gitCommand[ cmd, Directory[ ] ];

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseID*)
releaseID[ dir_ ] :=
    With[ { sha = Environment[ "GITHUB_SHA" ] },
        If[ StringQ @ sha,
            sha,
            gitCommand[ { "rev-parse", "HEAD" }, dir ]
        ]
    ];

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseURL*)
releaseURL[ file_ ] :=
    Enclose @ Module[ { pac, ver },
        pac = PacletObject @ Flatten @ File @ file;
        ver = ConfirmBy[ pac[ "Version" ], StringQ ];
        TemplateApply[
            "https://github.com/rhennigan/PacletCICD/releases/tag/v`1`",
            ver
        ]
    ];

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*actionURL*)
actionURL[ ] := Enclose[
    Module[ { cs, domain, repo, runID },
        cs     = ConfirmBy[ #, StringQ ] &;
        domain = cs @ Environment[ "GITHUB_SERVER_URL" ];
        repo   = cs @ Environment[ "GITHUB_REPOSITORY" ];
        runID  = cs @ Environment[ "GITHUB_RUN_ID"     ];
        cs @ URLBuild @ { domain, repo, "actions", "runs", runID }
    ],
    "$ACTION_URL$" &
];

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*updatePacletInfo*)
updatePacletInfo[ dir_ ] := Enclose[
    Module[
        { cs, file, string, id, date, url, run, cmt, new },

        cs     = ConfirmBy[ #, StringQ ] &;
        file   = cs @ FileNameJoin @ { dir, "PacletInfo.wl" };
        string = cs @ ReadString @ file;
        id     = cs @ releaseID @ dir;
        date   = cs @ DateString[ "ISODateTime", TimeZone -> 0 ];
        date   = StringTrim[ date, "Z" ] <> "Z";
        url    = cs @ releaseURL @ file;
        run    = cs @ actionURL[ ];
        cmt    = cs @ commitURL @ id;

        new = cs @ StringReplace[
            string,
            {
                "\r\n"           -> "\n",
                "$RELEASE_ID$"   -> id,
                "$RELEASE_DATE$" -> date,
                "$RELEASE_URL$"  -> url,
                "$ACTION_URL$"   -> run
            }
        ];

        Print[ "Updating PacletInfo"     ];
        Print[ "    ReleaseID:   ", id   ];
        Print[ "    ReleaseDate: ", date ];
        Print[ "    ReleaseURL:  ", url  ];
        Print[ "    ActionURL:   ", run  ];

        Confirm @ WithCleanup[ BinaryWrite[ file, new ],
                               Close @ file
                  ];

        updateReleaseInfoCell[ dir, url, cmt, run ]
    ],
    Function[
        Print[ "::error::Failed to update PacletInfo template parameters." ];
        Exit[ 1 ]
    ]
];



updateReleaseInfoCell[ dir_, url_, cmt_, run_ ] /;
    Environment[ "GITHUB_WORKFLOW" ] === "Release" :=
    Enclose @ Module[ { cells, nbFile, nb, rule },

        cells  = ConfirmMatch[ releaseInfoCell[ url, cmt, run ], { __Cell } ];
        nbFile = FileNameJoin @ { dir, "ResourceDefinition.nb" };
        nb     = ConfirmMatch[ Import[ nbFile, "NB" ], _Notebook ];
        rule   = Cell[ ___, CellTags -> { ___, "ReleaseInfoTag", ___ }, ___ ] :>
                     Sequence @@ cells;

        Export[ nbFile, nb /. rule, "NB" ]
    ];


commitURL[ sha_String ] :=
    URLBuild @ { "https://github.com/rhennigan/PacletCICD/commit", sha };


releaseInfoCell[ release_, commit_, run_ ] := Enclose[
    Module[ { environment },
        environment = ConfirmBy[ Environment[ #1 ], StringQ ] &;
        {
            Cell[
                TextData @ {
                    $tagIcon,
                    " ",
                    ButtonBox[
                        FileNameTake @ release,
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL @ release, None },
                        ButtonNote -> release
                    ]
                },
                "Text"
            ],
            Cell[
                TextData @ {
                    $commitIcon,
                    " ",
                    ButtonBox[
                        StringTake[ FileNameTake @ commit, 7 ],
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL @ commit, None },
                        ButtonNote -> commit
                    ]
                },
                "Text"
            ],
            Cell[
                TextData @ {
                    $actionIcon,
                    " ",
                    ButtonBox[
                        StringJoin[
                            environment[ "GITHUB_WORKFLOW" ],
                            "/",
                            environment[ "GITHUB_JOB" ]
                        ],
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL @ run, None },
                        ButtonNote -> run
                    ]
                },
                "Text"
            ]
        }
    ],
    None &
];

$tagIcon := $tagIcon = BinaryDeserialize @ ByteArray[ "\
OEM6eJy9VEuP40QQnhcLY5YRB5BWqz3ACrjk4MnYmSRIaMduPzP22I7txJ5bHt22x20762fiH4E4IcE\
F8QOQOHDgAhcuiB+AxIUbZ/4C3tkwi7IJEghRl+6q7ytV1detQgfZEYAYo/3sVTZZcpN8gg6z18V0sv\
CDWdaEUMNQgixvGMdNeKXAEuL088+e2S9PGvJrZr7CcINpNdlhDLMs3bu1r5806IkQYAznoEjLW/7hm\
n9/fa59sAcOwN6dtw8OweFfsP1/hf2XTOJ/6PefYkcbPe2Do50z/Y3XvN0JSKJF2jwdnD/7Dua3B0T7\
QzhYWpaa6GY0ClwRGGwkG5zBZ1zIgUrx3coQB3WPMxLZUed9n+bUSwp5T0fXfSASp1Etk4xdD+Bo2BL\
Olq5ECzptke5Vr6dyfb8bwAoaCVXTUodtTRFTqtNZPmhX+vSamHZsttcqU9lZKaMblmScrPRVMvQyWW\
Kw1UHdAofIRppA45vxslVVfDlxg75tLzyCdDSNVHipGEONpy298pRIP2MNr2R0i+znXJeXfER6VLstC\
FJ35YSjkDTCgbkcD4l6PE9iJtFKWhnwBVdNC2/FIjVWOIbpLW2NHM/E02GRMVgKmGVFMtIVGoXyR8Q7\
a9si5icvi8kY7PhWTNSVRd5zxKXnqWZMi75hFNdUrfatCvFOi5uRxiwg6nNGwuN5bWhyGYFwcdNbOsF\
lbhqaG3dl32KveMkKKJt1i9IVVHBqyEOdsj2Sm8hEmfiXGUcL7RU6d3URXceKjBh0FnYU+dwPAVQdds\
6bGCz8ItKTWUc958UIY1UnWSLNbQ+Fes1XjUieQDoxDvsGdba4IRkyLytzmIRko1PntOeVmYoH7agqK\
NRDFRkRVEsDraE6RB6nhLatvhDpjfXPW2+P9cJ4cLG+fHBxh4Cvgl+f/vT2FuR54K2L9Jsfy++/ePj+\
FuT55b0tyJc/07/3fnu8s87jzZwHW5Dvhp+++3Hn4c6cR1vq3CE7enu0ZZ6NOi9psKHbsMAwu2/mabD\
QYjleFHn2ijDBGbwDj4UkzkGCk3THhv+T+CY7ySAOYqgnWZAHSdzw75mzSbPRU+rWfnhBPpajiQfNoI\
bgxLynFXlT+Q+IwNpB" ];

$commitIcon := $commitIcon = BinaryDeserialize @ ByteArray[ "\
OEM6eJy1U81u00AQTppQaCgV4gAScIhAOSAj1UH5KxJq43UT54fYziZOnZvjrGvHjjd4nd9TH4AXgDu\
cuXDghMSFZ+AZeAk2jfubRMChc5md+b5vZna0a2yQKECOY4TJbQ5PeM3XjAi5W/S0gWnphKYMyqhaxK\
eMLZqeVtEIOd7HD3P7tU/Jd6A/ddA1ZoOqbRcR4oVO7cs+RXcKluOgLhh6oyv8aOAjCw/CIAoil6LIX\
6Lt/9CHaBz6p9o3xzy7973AB3GwqsTB4nASP1hGvn6e/nwxe3KBfHoJnv7+8SzQhB5d18RXIIsij9dq\
Hq7oc46smY0ip6Nwz9f1OUmsm+0ycvU+y5rEij7LewuTHYD7A48+QNSdP2r4fiOWfI3Kk0bjLZZgX7H\
UIpC5VknmZVmqiRksskDVrXxGVW3YF/dkBajFtNk1muNOnculxjHAVpUK5GcChHy5zadBw38FYNVTkj\
23ijkimSBHDg2rlm00jzxFcGSdNycjM0fMXAwf4kJbSnGpOleoScmKJqoe7tpSujdqZo9B1mOEcVNpj\
ZlyPU8k0tnlMGtLrJBO+92Ywnb6lckEKrbR6k3qTJMS9sp0Ar1kMu96Uz6vilDMCLm2kOOYDr9bYuyj\
cbZm8DYbY5imnq+We3VdfxOLBzZfXX3oILINfc8aiG7JHQx9cqugOQSdg1sF7PoAO9hb8/nPiPc5jSD\
HcpGEieVb2KX8Tahr9LMH5G/fL6qW+toxgtYMgQdwUxz6tPMf+lBLvw==" ];

$actionIcon := $actionIcon = BinaryDeserialize @ ByteArray[ "\
OEM6eJylVMtu00AUTZtQSFoqKrFgmR1IUUn6ygOpSuxx7Dgk1I6dKhYbTDyOjV+px4md/AYr2FIJiQV\
ii8SCr0BCYsMnsOuSaeWkURyLR2czvnPOuefOkTzqOkoBaJrqGrpNOgEle7KaRJuMKw81vY/wkYoZLR\
15mJHGx5MWHEPTffvmcn2vYvIdwZuYcIkpYrVhQ4TcxNX6VMXoNq2bJlTAyB1f8ZMhPxXuYQ3WQAokF\
6rkH6qb6tP/oE/gOvFXvf+Tqd4N9zDNMMCLaviRrUWRj8zP6f3HD6+Rr8+zxK93O7WQsrusya5AZk3i\
NLu1qM8ciZkNIz/oZLB5vhPrc1GNm20BWbpPRIMziPhEc1ud7NyvcK2FH16InfdbK5BEuNwv3usHqW+\
PViAxWWBk1jbOJ5GIm20BmRnHaQq1qM8ciZkNI5H7LPlEMljMbQ1tA8cauviHh8rlIyKcr2f2nsBmII\
pthxOsU11iCJ7YZ3mK51tN2jEaElXQLE4504F8KBlNq53zZYqR7Ak5FfhmOzOalMlykEOyL06Z8rDkq\
z79ypH4/JidtJ9VtHyvEtQbB5orqnWOkBjUmpJN0+iqiOtm/GJzUD4YaCrxUlUoKu/TDAt5taD1Sdy1\
a+mc0xILIlG0HK1k1519omQ9zQOJ94JSRuGhROU5biCzPalRBCNBrfd6yulRu3E2zCnUAVOH1Ik0PmQ\
OG+VgDMxiw+e7Z50cb/YyCinwlQ40NGAMrL2y3z7tk/u9Ix8SLMGAPdbgj48z2XBdRtoZmRBtCZ6rD0\
9s1h6OPHSLlk0E52CadmwPOKbjxjzCM+I9UkbQ1G3IOUj3dMfG/A2hL+NHNyR/vianWUseQEGfQrAtb\
JyMPOz8G6VppwM=" ];

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setResourceSystemBase*)
setResourceSystemBase[ ] := (
    Needs[ "ResourceSystemClient`" -> None ];
    $ResourceSystemBase =
        With[ { rsBase = Environment[ "RESOURCE_SYSTEM_BASE" ] },
            If[ StringQ @ rsBase, rsBase, $ResourceSystemBase ]
        ]
);

(* ::**********************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkResult*)
checkResult // Attributes = { HoldFirst };

checkResult[ eval: (sym_Symbol)[ args___ ] ] :=
    Module[ { result, ctx, name, stacks, stackName, full },

        result = noExit @ eval;
        ctx    = Context @ Unevaluated @ sym;
        name   = SymbolName @ Unevaluated @ sym;
        full   = ctx <> name;

        If[ $messageNumber > 0
            ,
            stackName = name <> "StackHistory";
            stacks = ExpandFileName[ stackName <> ".wxf" ];
            Print[ "::notice::Exporting stack data: ", stacks ];
            Export[
                stacks,
                <|
                    "Stacks"      -> $stackHistory,
                    "Environment" -> GetEnvironment[ ]
                |>,
                "WXF",
                PerformanceGoal -> "Size"
            ];
            EchoEvaluation @ setOutput[ "PACLET_STACK_HISTORY", stacks    ];
            EchoEvaluation @ setOutput[ "PACLET_STACK_NAME"   , stackName ];
        ];

        Print @ Select[
            SystemInformation[ "Kernel", "AllFilesLoaded" ],
            StringContainsQ[ "DefinitionNotebookClient" | "PacletResource" ]
        ];

        If[ MatchQ[ Head @ result, HoldPattern @ sym ]
            ,
            Print[ "::error::" <> full <> " not defined" ];
            Exit[ 1 ]
        ];

        If[ FailureQ @ result,
            Print[ "::error::" <> full <> " failed" ];
            Exit[ 1 ]
        ]
    ];

noExit    := Wolfram`PacletCICD`Private`noExit;
setOutput := Wolfram`PacletCICD`Private`setOutput;

(* ::**********************************************************************:: *)
(* ::Section::Closed:: *)
(*Setup*)
$pacDir = DirectoryName[ $InputFileName, 2 ];
Print[ "Paclet Directory: ", $pacDir ];

updatePacletInfo @ $pacDir;
PacletDirectoryLoad @ $pacDir;
Needs[ "Wolfram`PacletCICD`" -> None ];

setResourceSystemBase[ ];
Print[ "ResourceSystemBase: ", $ResourceSystemBase ];

$defNB = File @ FileNameJoin @ { $pacDir, "ResourceDefinition.nb" };
Print[ "Definition Notebook: ", $defNB ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];
