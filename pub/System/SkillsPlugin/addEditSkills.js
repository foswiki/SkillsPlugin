SkillsPlugin.addEditSkills = function () {
    
    // hides the 'clear comment' button
    var _hideClearComment = function(){
        var el = document.getElementById("addedit-skill-comment-clear");
        if (el != null)
            el.style.display = 'none';
    }
    
    // shows the 'clear comment' button
    var _showClearComment = function(){
        var el = document.getElementById("addedit-skill-comment-clear");
        if (el != null)
            el.style.display = '';
    }
       
    // resets the entire form to its initial state
    var _resetForm = function(){
        SkillsPlugin.main.populateCategorySelect('addedit');
    }
       
    return {
        // clears the rating and the comment
        resetSkillDetails: function(){
            // reset details
            var yuiEl = new YAHOO.util.Element();
            var els = yuiEl.getElementsByClassName('skillsRating');
            for( var i in els) {
                if (els[i].checked )
                    els[i].checked = false;
            }
            var els = yuiEl.getElementsByClassName('skillsComment');
            for( var i in els)
                els[i].value = '';
            _hideClearComment();
        },

        // populates the rating and the comment for a skill
        populateSkillDetails: function() {
            this.resetSkillDetails();

            // get selected category and skill
            var elSelect = document.getElementById(
                "addedit-category-select");
            var cat = elSelect.options[elSelect.selectedIndex].value;

            elSelect = document.getElementById("addedit-subcategory-select");
            var subcat = (elSelect ?
                          elSelect.options[elSelect.selectedIndex].value
                          : -1);

            elSelect = document.getElementById("addedit-skill-select");
            var skill = elSelect.options[elSelect.selectedIndex].value;

            var cbSkillDetails = function( skid ){
                if (!skid.rating == null)
                    skid.rating = 0;
                var yuiEl = new YAHOO.util.Element();
                var els = yuiEl.getElementsByClassName('skillsRating');

                // select the rating radio button
                for( var i in els) {
                    if( els[i].value == skid.rating ){
                        els[i].checked = true;
                        break;
                    }
                }
                
                if( skid.comment != null ){
                    // set comment
                    var elComment = document.getElementById(
                        "addedit-skill-comment");
                    if (elComment != null)
                        elComment.value = skid.comment;
                    _showClearComment();
                }
                SkillsPlugin.main.unlockForm();
            }

            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.get(
                "getSkillDetails?path1=" + encodeURIComponent(cat)
                + ((subcat < 0) ? '' : ";path2=" + encodeURIComponent(subcat))
                + ";path3=" + encodeURIComponent(skill),
                cbSkillDetails, cat, skill);
        },
        
        // submits the form
        submit: function() {
            SkillsPlugin.main.submit(
                'addEditSkill', 'addedit-skill-form',
                "addedit-skills-message",
                _resetForm);
        },
        
        // clears the comment text field
        clearComment: function(){
            var elComment = document.getElementById("addedit-skill-comment");
            if (elComment != null)
                elComment.value = '';
            _hideClearComment();
        },
        
        // react to a key press in the comment text box
        commentKeyPress: function(e){
            var el = YAHOO.util.Event.getTarget(e);
            if( el.value.length == 0 ){
                _hideClearComment();
            } else {
                _showClearComment();
            }
        }
    };
}();

// register events
YAHOO.util.Event.onAvailable(
    "addedit-category-select",
    function () {
        SkillsPlugin.main.populateCategorySelect('addedit');
    },
    SkillsPlugin.addEditSkills, true);

YAHOO.util.Event.addListener(
    "addedit-category-select", "change",
    function() {
        var elSelect = document.getElementById("addedit-subcategory-select");
        this.resetSkillDetails();
        if (elSelect)
            SkillsPlugin.main.populateSubCategorySelect('addedit');
        else
            SkillsPlugin.main.populateSkillSelect('addedit');
    }, SkillsPlugin.addEditSkills, true);

YAHOO.util.Event.addListener(
    "addedit-subcategory-select", "change",
    function() {
        this.resetSkillDetails();
        SkillsPlugin.main.populateSkillSelect('addedit');
    }, SkillsPlugin.addEditSkills, true);

YAHOO.util.Event.addListener(
    "addedit-skill-select", "change",
    function () {
        this.populateSkillDetails();
    },
    SkillsPlugin.addEditSkills, true);

YAHOO.util.Event.addListener(
    "addedit-skill-comment", "keyup",
    this.commentKeyPress,
    SkillsPlugin.addEditSkills, true);

YAHOO.util.Event.addListener(
    "addedit-skill-comment-clear", "click",
    this.clearComment,
    SkillsPlugin.addEditSkills, true);

YAHOO.util.Event.addListener(
    "addedit-skill-submit", "click",
    function () { this.submit() },
    SkillsPlugin.addEditSkills, true);
