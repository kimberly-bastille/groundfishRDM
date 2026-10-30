# Recreational Decision Support Tool User Guide for Western Gulf of Maine Cod and Gulf of Maine Haddock

This Decision Support Tool (DST) helps fishery management stakeholders answer a practical question: if we set a particular combination of seasons, bag limits, and minimum sizes for recreational cod and haddock next fishing year, what is likely to happen? The DST projects recreational fishing mortality, the number of fishing trips anglers are expected to take, and changes in angler well-being under different combinations of fishing regulations.

The tool is built for fishery managers, agency staff, and other stakeholders who need to compare candidate management measures before a decision. This guide explains how the DST works, walks through the app, and describes how to interpret the results.

## Overview

Managing recreational fisheries presents challenges that differ from those in commercial fisheries. In many commercial fisheries, landings are reported and monitored in near real time, allowing managers to track catch against a quota and take in-season action when necessary. Recreational fisheries involve a much larger and more dispersed population of participants, and catch and effort are typically estimated through surveys rather than observed comprehensively in real time. As a result, managers generally cannot directly control aggregate recreational harvest to meet a recreational harvest limit. Instead, they set seasons, bag limits, and size limits that are expected to achieve management objectives.

These regulations affect recreational fishing mortality through two related pathways. First, they directly affect what happens on a fishing trip by determining which encountered fish anglers can retain and which must be released. Second, regulations can change the expected quality and value of a fishing trip, causing anglers to change how often they go fishing. Realized recreational fishing mortality therefore depends both on the direct effects of regulations on catch and disposition and on anglers' behavioral responses to those regulations. The DST takes both pathways into account when projecting fishery-wide outcomes.

### What the tool is built on

Four kinds of information feed the tool.

**What anglers value.** In 2025, anglers in Maine, New Hampshire, and Massachusetts were surveyed about their fishing trip preferences. Each person was shown pairs of hypothetical trips that differed in how many cod and haddock they caught that could be harvested, how many would have to be released, and what the trip would cost. They were asked which trip they would choose, or whether they would rather not fish at all. Their answers reveal the relative value anglers place on harvestable and released cod and haddock and allow us to estimate how expected catch affects the likelihood that an angler takes a fishing trip. These preferences are the behavioral engine of the tool. You can view a sample of the survey [here](GulfofMaineCodandHaddockSurvey2025.pdf).

**What anglers actually catch.** Historical catch and effort data from the Marine Recreational Information Program (MRIP) tell us how many trips are taken, when they occur, and by which fishing mode. They also tell us how many cod and haddock are caught on a typical trip. MRIP estimates have sampling uncertainty because MRIP surveys a sample of fishing trips rather than observing every trip. Fishing outcomes also vary naturally: most trips catch few fish, while a small number catch many. The the [RecDST data dashboard](https://connect.fisheries.noaa.gov/content/c257deee-a657-4c10-be8a-92827cb5bdfe/) provides additional information about the MRIP data used in the tool.

**How big the fish are.** Stock assessments project the number of cod and haddock in the population next year for each age class. This matters for recreational management because the effect of a minimum size limit depends on how many fish are near that size. Combined with information about the sizes anglers have caught in the recent past, these projections allow us to estimate next year's expected catch-at-length distributions, or the lengths of fish anglers are likely to encounter.

**What trips cost.** NOAA's 2022 angler expenditure survey, an add-on to the site-intercept survey, provides information on fishing trip costs. We use these data to translate policy-induced changes in trip quality into monetary changes in angler well-being.

### How the DST represents uncertainty

Many inputs to the DST are estimates rather than exact values. For example, MRIP catch and effort estimates are based on surveys, stock assessment projections are uncertain, and angler preferences are estimated from survey responses. The DST accounts for these sources of uncertainty by evaluating each regulatory scenario many times using different plausible values for these inputs. We call each of these evaluations a draw.

Unless otherwise noted, results shown in the DST are the median across draws. The median is the middle projected outcome: half of the draws produce a higher value and half produce a lower value. We use the median because it is less sensitive than an average to a small number of extreme projected outcomes.

For recreational mortality, the DST also reports the percentage of draws at or below the sub-ACL. This provides additional information about uncertainty around the median. For example, two regulatory scenarios could have similar median mortality but different percentages of draws below the sub-ACL. A higher percentage means the scenario remains below the sub-ACL across a wider range of plausible fishery conditions represented by the model.

The median and the percentage of draws below the sub-ACL should be read together. The median describes the central projected outcome, while the percentage below the sub-ACL describes how consistently the scenario meets the limit across the plausible conditions represented in the DST.

### What the simulation actually does

The simulation builds up a fishery-wide answer from many small, realistic pieces. Rather than applying one average rule to the whole fishery, the tool represents a very large number of individual fishing opportunities, works through each one, and then adds up the results.

Here is a simplified version of what happens for a single opportunity - think of it as one person, on one day, deciding whether to go fishing.

**1. Set the scene.** The tool assigns this person a trip cost and personal characteristics, such as age, education, and how often they fished in the past year, drawn from realistic distributions.

**2. Figure out what they would catch.** The tool draws a number of cod and haddock from observed catch-per-trip patterns for that time of year and fishing mode. It then assigns each individual fish a length drawn from the length distribution anglers are expected to encounter next year.

**3. Apply the rules.** Each fish is checked against the minimum size and bag limit in effect on that date and for that fishing mode. Legal fish are kept until the bag limit is reached; everything else is released. Some released fish die, and the tool accounts for this using discard mortality rates that vary by month and fish size (for haddock). Observed fishery data are also used to represent imperfect compliance and voluntary release: some fish that are legally required to be released are harvested, while some fish that could legally be kept are released.

**4. Decide whether the trip happens.** The tool now knows what the trip would be like - including the expected number of cod and haddock harvested and released and the trip cost. Using preference parameters estimated from the angler survey, it calculates how appealing the trip is relative to not fishing and converts that value into the probability that the angler takes the trip. Across all fishing opportunities, these probabilities determine the projected number of recreational cod and haddock trips.

The tool repeats this process for fishing opportunities throughout the year and aggregates the outcomes. Because each opportunity's contribution is weighted by the probability that the trip occurs, regulations that make fishing less attractive result in fewer projected trips and, all else equal, less fishing mortality.

We always provide a set of results for "last year's" conditions and rules, giving a baseline for comparison for the same person on the same day.

### Assumptions worth knowing about

A few modeling choices shape how you should read the results.

**Catch rates do not respond to abundance directly.** More fish in the water changes the sizes anglers are expected to encounter, and therefore what they can keep, but it does not directly change how many fish they hook on a trip.

**Numbers and lengths are drawn independently.** How many fish a trip catches and how big those fish are are treated as unrelated, and cod catch and haddock catch-per-trip are computed separately.

## Using the App

### Getting Started

Before you start: the app does not process the model while you wait on the page. When you submit a scenario, the app saves your regulations and places the scenario in a queue. The model processes it in the background, which can take some time. Results appear on the summary page once processing is complete.

The app opens with two tabs across the top.

**Cod and Haddock Model Summary** is where you view results. It shows regulatory scenarios that have finished processing so you can compare candidate regulations with one another and with the status quo.

**Regulation Selection** is where you build and submit a new regulatory scenario.

------------------------------------------------------------------------

![Figure 1: Screenshot of the two main two main tabs at the top of the app, with the summary page open](figures/SummaryPage.png)

------------------------------------------------------------------------

### Building a Scenario: the Regulation Selection Tab

This tab is laid out in two columns, cod on the left and haddock on the right. Each species has its own seasons, bag limits, and minimum sizes, and each is set separately for the two modes: For Hire and Private.

Everything is pre-loaded with the status quo regulations (regulations in place in the most recent fishing year). If you only want to evaluate one change, you can change that control and leave the rest unchanged.

#### Step 1: Name your scenario

At the top is a box asking you to name the regulatory scenario you are considering. We recommend using your initials and a number - AB1, AB2, and so on. This label will be attached to the results, so choose something you will recognize later. Each proposed scenario needs a different name so that scenarios can be distinguished in the results.

------------------------------------------------------------------------

![Figure 2: Screenshot of scenario name box and the Run Me button at the top of the Regulation Selection tab](figures/ScenarioNameBox.png)

------------------------------------------------------------------------

#### Step 2: Set the cod regulations

The cod column starts with **For Hire Season 1** - a pair of date boxes for the season's opening and closing dates. Underneath are two controls that apply to that season:

**Bag Limit** - the number of cod an angler may keep per day. Type a number. **Min Length** - the minimum size in inches, set with a slider in one-inch steps.

Below that, the same three controls appear again for **Private Season 1**.

**Adding a second cod season.** If you wish to evaluate a scenario with two cod open seasons, click Add Season. A second block appears with dates, bag limit, and minimum size for both modes. Cod supports two seasons in total.

------------------------------------------------------------------------

![Figure 3: Screenshot of cod column showing For Hire Season 1 dates, bag limit, and minimum length slider](figures/CodColumn1.png)

------------------------------------------------------------------------

#### Step 3: Set the haddock regulations

The haddock column works the same way, with one difference: two seasons are visible from the start for each mode, and clicking **Add Season** reveals a third. Haddock supports three seasons in total.

![Figure 4: Screenshot of the haddock column showing both visible seasons for For Hire and Private](figures/HaddockColumn.png)

**How seasons and closures are handled** Two rules govern how your dates are turned into a fishing calendar:

**Any day not covered by a season is closed.** You do not need to enter dates for a proposed closure. If a date falls outside every open season you have set for a species and mode, no fish of that species may be kept that day.

**If seasons overlap, the higher-numbered season overrules the lower-numbered season.** For example, if Season 1 runs May through October with a 15-fish bag limit and Season 2 runs September through October with a 5-fish bag limit, September and October will use the 5-fish bag limit. This is useful when you want a broad season with a more restrictive period within it: set the broad rules as Season 1 and the exception as Season 2.

To close a season you have opened, set its bag limit to zero. Seasons with a zero bag limit are dropped from the results tables so they do not clutter the comparison.

#### Step 4: Submit the proposed scenario

When your regulations are set, click Run Me.

**Click it only once.** The button does not provide much feedback, and clicking it repeatedly will submit the same scenario more than once. After one click, a message confirms that your regulations were saved and the scenario was queued.

If you want to submit another scenario, change the scenario name first, adjust the regulations, and click **Run Me** again.

### Viewing Results: the Summary Tab

Return to the **Cod and Haddock Model Summary** tab. Results do not appear automatically - click the **Update** button near the top to refresh the page and display scenarios that have finished processing since you opened the app.

The page has three parts, from top to bottom: a chart comparing cod and haddock mortality across regulatory scenarios, a table with the details behind each scenario, and a set of optional figures you can turn on.

------------------------------------------------------------------------

![Figure 5: Screenshot of the Update button at the top of the summary page](figures/UpdateButton.png)

------------------------------------------------------------------------

The **Supplemental Figures** selector: Below the main table is a row of checkboxes labeled Supplemental Figures, with three choices: **Compensating Variation**, **Discards**, and **Trips**. Each box you select adds two figures to the bottom of the page - one for cod and one for haddock. Clear a box and its figures disappear. These figures are described below.

![Figure 6: Screenshot of the Supplemental Figures checkbox row](figures/SupplementalFigures.png)

------------------------------------------------------------------------

### Interpreting Your Results

Start with the mortality chart and summary table. Together they address the main management question: does a regulatory scenario lead to recreational fishing mortality at or below the sub-ACL? The supplemental figures provide additional information about angler welfare, discards, and fishing trips.

#### The Cod and Haddock Mortality Chart

This chart provides a quick way to compare projected recreational mortality across regulatory scenarios. Each point represents one scenario and is labeled with the name provided by the user. **The horizontal position** is projected recreational cod mortality in metric tons. **The vertical position** is projected recreational haddock mortality in metric tons.

Recreational mortality is the weight of fish harvested plus the weight of released fish that do not survive.

Two reference lines are drawn on the chart. A dashed vertical line marks the recreational cod sub-ACL, and a horizontal line marks the recreational haddock sub-ACL. Points to the left of the cod line are below the cod sub-ACL; points below the haddock line are below the haddock sub-ACL; points in the lower-left region meet both sub-ACLs.

Point color provides additional information about uncertainty. It shows the percentage of draws in which cod mortality is at or below the cod sub-ACL. A higher percentage means the scenario remains below the cod limit across a wider range of plausible fishery conditions represented by the model. Two scenarios can have similar median mortality but different colors if one stays below the cod sub-ACL more consistently across draws.

A note on the legend: it lists a second category for the haddock limit tied to point size, but every point is currently drawn the same size, so that part of the legend has no visual effect. Use the summary table for the percentage of draws below the haddock sub-ACL. Hover over any point to see the detailed numbers behind it.

------------------------------------------------------------------------

![Figure 7: Screenshot of cod versus haddock mortality chart with reference lines and scenario labels](figures/CodVsHaddockMortality.png)

------------------------------------------------------------------------

### The Summary Table

Below the chart is a sortable table with one row per regulatory scenario and mode. Click any column heading to sort by it.

| Column | What it shows |
|----|----|
| **Policy identifier** | The name you gave the regulatory scenario |
| **Mode** | For Hire or Private |
| **Cod season(s)** | The open dates you set, as month and day |
| **Cod bag limit** | Fish per angler per day |
| **Cod minimum size (in)** | Minimum length in inches |
| **Haddock season(s)** | The open dates you set |
| **Haddock bag limit** | Fish per angler per day |
| **Haddock minimum size (in)** | Minimum length in inches |
| **Cod rec. mortality** | Total recreational cod mortality, in metric tons |
| **Haddock rec. mortality** | Total recreational haddock mortality, in metric tons |
| **% under Cod ACL** | Percentage of draws at or below the cod sub-ACL |
| **% under Haddock ACL** | Percentage of draws at or below the haddock sub-ACL |

The mortality columns and the "% under" columns should be interpreted using the uncertainty framework described near the beginning of this guide. The mortality columns show the central projected outcomes, while the "% under" columns show how consistently each scenario remains below the applicable sub-ACL across the model's plausible draws.

------------------------------------------------------------------------

![Figure 8: Screenshot of the summary table showing regulation columns and mortality columns for several scenarios](figures/SummaryTable.png)

------------------------------------------------------------------------

### Understanding Compensating Variation

The DST computes compensating variation (CV) to measure how a proposed regulatory scenario changes angler well-being relative to the baseline (i.e., the previous year). CV expresses that change in dollars, but it is not angler spending, revenue, income, or a payment that anglers actually receive. Instead, it represents the amount of money that would need to be given to or taken from anglers under the proposed regulations to leave them as well off as they were under the baseline.

**Positive CV means anglers are worse off under the proposed regulations.** A positive value is the amount anglers would need to receive to compensate them for the reduction in fishing quality. For example, a CV of \$1 million means anglers would collectively need \$1 million in compensation to be as well off as under the baseline.

**Negative CV means anglers are better off under the proposed regulations.** In this case, money could theoretically be taken away from anglers while still leaving them as well off as under the baseline. For example, a CV of -\$1 million represents a \$1 million improvement in angler well-being relative to the baseline.

CV should therefore be interpreted as the economic value of a change in expected fishing opportunities, not as money that is actually paid to or received by anglers. When comparing scenarios with similar conservation outcomes, a lower positive CV indicates a smaller cost to anglers, and a more negative CV indicates a larger improvement in angler well-being.

### Compensating Variation Figures

Select the CV box to add two figures, one for cod and one for haddock. Each figure plots compensating variation on the horizontal axis, in millions of dollars, against that species' total recreational mortality on the vertical axis. A reference line marks the sub-ACL. These figures show the trade-off between conservation outcomes and changes in angler well-being. Two regulatory scenarios that produce similar mortality can have substantially different CV values. Scenarios farther to the left have lower CV and therefore represent better outcomes for anglers, all else equal. When comparing scenarios with similar mortality, the policy with the lowest CV is most ideal for anglers.

------------------------------------------------------------------------

![Figure 9: Screenshot of the angler satisfaction versus cod mortality figure](figures/ChangeInAnglerSatisfaction.png)

------------------------------------------------------------------------

### Discards Figures

Select the **Discards** box to add two figures. Each plots dead discard mortality on the horizontal axis against that species' total recreational mortality on the vertical axis, both in metric tons, with the sub-ACL marked.

**Why this matters.** Total recreational mortality is landings plus dead discards, so these figures show how much of a scenario's projected mortality comes from fish that were released and did not survive rather than from fish that were taken home. This is particularly important when evaluating high minimum size limits. Raising the minimum size can lower landings but may also increase releases, a share of which die. A scenario that shifts mortality from landings to dead discards may provide little additional conservation benefit while reducing the number of fish anglers can harvest.

------------------------------------------------------------------------

![Figure 10: Screenshot of discard mortality versus total mortality figure for cod](figures/DiscardFigures.png)

------------------------------------------------------------------------

### Trips Figures

Select the **Trips** box to add two figures, plotting the predicted number of recreational trips against each species' total mortality.

**What this tells you.** The trip count is the tool's estimate of how many trips anglers are expected to take. Because the tool accounts for whether expected fishing conditions make a trip more or less attractive, more restrictive regulations can reduce the projected number of trips. Changes in trips can also indicate economic effects beyond angler welfare, such as changes in spending at businesses that serve recreational anglers.

------------------------------------------------------------------------

![Figure 11: Screenshot of predicted trips versus mortality figure](figures/TripFigures.png)

------------------------------------------------------------------------

## Questions or Feedback

If you have questions about this tool, need help interpreting a regulatory scenario, or want to suggest an improvement, contact the RecDST team at [nefsc.recdst\@noaa.gov](mailto:nefsc.recdst@noaa.gov){.email}.
