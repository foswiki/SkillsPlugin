SkillsPlugin.searchSkills = function () {
    return {
        // submits the form
        submit: function(){
            var _populateResults = function( results ){
                var elResults = document.getElementById(
                    "search-skill-results");
                elResults.innerHTML = results;
            };

            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.submit(
                'search', "search-skill-form",
                0, //"search-skills-message",
                function(o) {
                    _populateResults(o.responseText);
                });
        }
    };
    
}();

// register events
YAHOO.util.Event.onAvailable(
    "search-category-select",
    function () {
        SkillsPlugin.main.populateCategorySelect('search');
    },
    SkillsPlugin.searchSkills, true);
            
YAHOO.util.Event.addListener(
    "search-category-select", "change",
    function () {
        var elSelect = document.getElementById(
            "search-subcategory-select");
        if (elSelect)
            SkillsPlugin.main.populateSubCategorySelect('search');
        else
            SkillsPlugin.main.populateSkillSelect('search');
    },
    SkillsPlugin.searchSkills, true);
            
YAHOO.util.Event.addListener(
    "search-subcategory-select", "change",
    function () {
        SkillsPlugin.main.populateSkillSelect('search');
    },
    SkillsPlugin.searchSkills, true);

YAHOO.util.Event.addListener(
    "search-skill-submit", "click",
    SkillsPlugin.searchSkills.submit,
    SkillsPlugin.searchSkills, true);


