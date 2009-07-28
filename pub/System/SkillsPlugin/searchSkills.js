SkillsPlugin.searchSkills = function () {
    return {
        // submits the form
        submit: function(){
            SkillsPlugin.main.submit(
                'search', "search-skill-form",
                function(o) {
                    var elResults = document.getElementById(
                        "search-skill-results");
                    elResults.innerHTML = o.responseText;
                });
        }
    };
    
}();

// register events
YAHOO.util.Event.addListener(
    "search-category-select", "change",
    function () {
        SkillsPlugin.main.populateSkillSelect('search');
    },
    SkillsPlugin.searchSkills, true);
            
YAHOO.util.Event.addListener(
    "search-skill-submit", "click",
    SkillsPlugin.searchSkills.submit,
    SkillsPlugin.searchSkills, true);


