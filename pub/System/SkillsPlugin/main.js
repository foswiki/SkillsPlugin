if( !SkillsPlugin )
    var SkillsPlugin = {};

SkillsPlugin.main = function() {
    
    return {
        tt_map: {},
        tt_els: [],

        init: function() {

        },

        twist: function( elTwistyLink ) {
            var yuiEl = new YAHOO.util.Element();
            
            var twistyId = elTwistyLink.id.replace( /_.*$/, '');
            
            var elsToTwist = yuiEl.getElementsByClassName(
                twistyId + '_twist' );
            
            var elTwistyImgCont;
            var elTwistyImg;
            if( elTwistyImgCont = document.getElementById(
                    twistyId + '_twistyImage' ) ){
                elTwistyImg = document.getElementById(
                    twistyId + '_twistyImage' ).childNodes[1];
            }
            
            // are we open or close?
            var elTwistyLink = new YAHOO.util.Element(elTwistyLink);
            if( elTwistyLink.hasClass( 'twistyopen' ) ){
                elTwistyLink.replaceClass( 'twistyopen', 'twistyclosed' );
                for( var i in elsToTwist ){
                    this.closeTwist( elsToTwist[i], elTwistyImg );
                }
            }
            else if( elTwistyLink.hasClass( 'twistyclosed' ) ){
                elTwistyLink.replaceClass( 'twistyclosed', 'twistyopen' );
                var i;
                for( i in elsToTwist ){
                    this.openTwist( elsToTwist[i], elTwistyImg );
                }
            } else {
                elTwistyLink.addClass( 'twistyclosed' );
                var i;
                for( i in elsToTwist ){
                    this.closeTwist( elsToTwist[i], elTwistyImg );
                }
            }
        },
        
        openTwist: function( twistEl, imageEl ) {
            try {
                twistEl.style.display = '';
            } catch(e) {
                twistEl.style.display = 'block';
            }
            if( imageEl ){
                imageEl.src = SkillsPlugin.vars.twistyCloseImgSrc;
            }
        },
        
        closeTwist: function( twistEl, imageEl ) {
            twistEl.style.display = 'none';
            if( imageEl ){
                imageEl.src = SkillsPlugin.vars.twistyOpenImgSrc;
            }
        },

        // enable/disable inputs for the given class
        enableByClassName: function(className, enable){
            var yuiEl = new YAHOO.util.Element();
            var els = yuiEl.getElementsByClassName(className);
            for (var i in els) {
                els[i].disabled = !enable;
            }
        },

        enableById: function(id, enable){
            var el = document.getElementById(document, id);
            if (el != null)
                el.disabled = !enable;
        },

        // common function for all connection failures
        _connectionFailure: function(o){
            alert("Connection failure '" + o.statusText + "'. Please notify your administrator, giving the reason for this failure and as much information about the problem as possible.");
        },
    
        // gets the categories from the server
        getCategories: function( fnCallback ){
            var url = SkillsPlugin.vars.restUrl +
            "/SkillsPlugin/getCategories";
        
            var obCallbacks = {
                success: function(o){                
                    var arCats = YAHOO.lang.JSON.parse(o.responseText);
                    arCats.sort();
                    fnCallback( arCats );
                },
                failure: function(o){_connectionFailure(o)}
            }
            var request = YAHOO.util.Connect.asyncRequest(
                'GET', url, obCallbacks); 
        },
    
        // gets the skills from the server
        getSkills: function( category, fnCallback ){
            var url = SkillsPlugin.vars.restUrl + "/SkillsPlugin/getSkills";
            url += "?category=" + encodeURIComponent(category);
        
            var obCallbacks = {
                success: function(o){                
                    // TODO: need to check there are some skills!!
                    var arSkills = YAHOO.lang.JSON.parse(o.responseText);
                    arSkills.sort();
                    fnCallback( arSkills, category );
                },
                failure: function(o){
                    _connectionFailure(o);
                }
            }
            var request = YAHOO.util.Connect.asyncRequest(
                'GET', url, obCallbacks);
        },
    
        // gets the skills with associated rating and the comment
        getSkillsAndDetails: function( category, fnCallback ){
            var url = SkillsPlugin.vars.restUrl
            + "/SkillsPlugin/getSkillsAndDetails";
            url += "?category=" + encodeURIComponent(category);
        
            var obCallbacks = {
                success: function(o){
                    var obData = YAHOO.lang.JSON.parse(o.responseText);
                    fnCallback( obData, category );
                },
                failure: function(o){_connectionFailure(o)}
            }
            var request = YAHOO.util.Connect.asyncRequest(
                'GET', url, obCallbacks);
        },

        // gets the rating and the comment for a particular skill
        // from the server
        getSkillDetails: function( category, skill, fnCallback ){
            var url = SkillsPlugin.vars.restUrl
            + "/SkillsPlugin/getSkillDetails";
            url += "?category=" + encodeURIComponent(category);
            url += "&skill=" + encodeURIComponent(skill);
        
            var obCallbacks = {
                success: function(o){
                    var obSkillDetails = YAHOO.lang.JSON.parse(o.responseText);
                    fnCallback( obSkillDetails );
                },
                failure: function(o){_connectionFailure(o)}
            }
            var request = YAHOO.util.Connect.asyncRequest(
                'GET', url, obCallbacks);
        },

        tipify: function(el, cat, skill) {
            var id = cat;
            if (skill != null)
                id += '.' + skill;
            if (this.tt_map[id] == null)
                this.tt_map[id] = new Array();
            this.tt_map[id].push(el.id);
        },

        genTips: function() {
            var el = document.getElementsByTagName('BODY');
            el[0].className = 'yui-skin-sam';
            this.tooltips = new Array();
            for (var ttid in this.tt_map) {
                var div = document.getElementById(ttid);
                if (div == null) {
                    continue;
                }
                var text = div.innerHTML;
                var ids = this.tt_map[ttid].join(',');
                var ttel = new YAHOO.widget.Tooltip(
                    ttid + "Tooltip",
                    { context: this.tt_map[ttid], text: text } );
                delete this.tt_map[ttid];
            }
        },

        submit: function(rest, formid, messid, fnCallback) {
            var url = SkillsPlugin.vars.restUrl + '/SkillsPlugin/' + rest;
            var obForm = document.getElementById(formid);
            YAHOO.util.Connect.setForm(obForm);

            var obCallbacks = {
                success: function(o){
                    SkillsPlugin.main.unlockForm();
                    if (fnCallback)
                        fnCallback(o);
                    SkillsPlugin.main.displayMessage(o.responseText, messid);
                },
                failure: function(o){
                    SkillsPlugin.main.unlockForm();
                    SkillsPlugin.main._connectionFailure(o);
                }
            }

            SkillsPlugin.main.lockForm();
            YAHOO.util.Connect.asyncRequest('POST', url, obCallbacks);
        },

        // lock form when AJAX in progress
        lockForm: function(){
            SkillsPlugin.main.enableByClassName('skillsControl', false);
        },
    
        // unlocks the form
        unlockForm: function(){
            SkillsPlugin.main.enableByClassName('skillsControl', true);
        },

        initTwisty: function(){
            // sets up the twisty
            var yuiEl = new YAHOO.util.Element();
            
            if ( SkillsPlugin.vars.twistyState == 'off' ){
                return;
            }
            
            var arEls = yuiEl.getElementsByClassName(
                'SkillsPlugin-twisty-link', 'span');
            
            var fnTwistCallback = function(){
                SkillsPlugin.main.twist( this );
            };
            
            // add event to an array of elements
            YAHOO.util.Event.addListener(
                arEls,
                "click",
                fnTwistCallback
                );
            
            // loop over all twisty links
            for ( var i = arEls.length - 1; i >= 0; --i ){
                var twistyId = arEls[i].id.replace( /_.*$/, '');
                
                var elLink = new YAHOO.util.Element(
                    twistyId + '_twistyLink' );
                elLink.addClass('active');
                var elImg = new YAHOO.util.Element(
                    twistyId + '_twistyImage' );
                elImg.addClass('active');
                
                // set initial state
                if( SkillsPlugin.vars.twistyState == 'closed' ){
                    SkillsPlugin.main.twist( arEls[i] );
                }
            }
        },

        // displays a notification recieved from the server
        displayMessage: function(message, id){
		
            var elMessage = document.getElementById(id);
            elMessage.innerHTML = message;
		
            this.showMessage( id );
        },
	
        // shows the message
        showMessage: function(id){
            var elMessageContainer = document.getElementById(
                id + '-container');
            elMessageContainer.style.display = '';
            // message is shown for 10 seconds
            var obAnim = new YAHOO.util.Anim(
                elMessageContainer,
                {
                  opacity: {to: 0, from:1}
                }, 
                10
                );
            obAnim.animate();
        },

        createTooltips: function() {
            var yuiEl = new YAHOO.util.Element();
            var els = yuiEl.getElementsByClassName('skillsTipped');
            for (var i = 0; i < els.length; i++) {
                this._setTooltip(els[i]); 
            }
        }
    }
}();
//SkillsPlugin.main.init();

SkillsPlugin.viewUserSkills = function () {
    
    return {
        
        init: function(){
            YAHOO.util.Event.onDOMReady(
                SkillsPlugin.main.initTwisty, this, true);
        }
    }
}();
if( SkillsPlugin.vars.viewUserSkills ){ 
    SkillsPlugin.viewUserSkills.init();
}

SkillsPlugin.addEditSkills = function () {
    
    var
    _idRating       = "addedit-skill-rating",
    _idComment      = "addedit-skill-comment",
    _idClearComment = "addedit-skill-comment-clear",
    _idSubmit       = "addedit-skill-submit",
    _idMessageContainer = "addedit-skills-message-container",
    _idMessage      = "addedit-skills-message";
        
    // hides the 'clear comment' button
    var _hideClearComment = function(){
        var el = document.getElementById(_idClearComment);
        if (el != null)
            el.style.display='none';
    }
    
    // shows the 'clear comment' button
    var _showClearComment = function(){
        var el = document.getElementById(_idClearComment);
        if (el != null)
            el.style.display='';
    }
    
    // clears the rating and the comment
    var _resetSkillDetails = function(){
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
    }
    
    // resets the entire form to its initial state
    var _resetForm = function(){
        // Reset skill select
        var elSkillSelect = document.getElementById("addedit-skill-select");
        if (elSkillSelect != null)
            elSkillSelect.options.length = 0;
        SkillsPlugin.addEditSkills.populateCategories();
    }
       
    return {
        
        init: function(){
            this.locked = false;

            // register events
            YAHOO.util.Event.onAvailable(
                "addedit-category-select", this.populateCategories,
                this, true);
           
            YAHOO.util.Event.addListener(
                "addedit-category-select", "change", this.populateSkills,
                this, true);
            YAHOO.util.Event.addListener(
                "addedit-skill-select", "change", this.populateSkillDetails,
                this, true);
            
            YAHOO.util.Event.addListener(
                _idComment, "keyup", this.commentKeyPress, this, true);
            
            YAHOO.util.Event.addListener(
                _idClearComment, "click", this.clearComment, this, true);
            YAHOO.util.Event.addListener(
                _idSubmit, "click", this.submit, this, true);
        },
        
        // populates the category select menu
        populateCategories: function(){
            var elCatSelect =
            document.getElementById("addedit-category-select");
            if (elCatSelect == null)
                return;

            elCatSelect.options.length = 0;
            _resetSkillDetails();

            if( SkillsPlugin.vars.loggedIn == 0 ){
                elCatSelect.options[0] = new Option("Please log in...", "0", true);
                SkillsPlugin.main.lockForm();
                return;
            }
            elCatSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arCats ){
                elCatSelect.options[0] = new Option("Select a category...", "0", true);
                var count = 1;
                for( var i in arCats ){
                    elCatSelect.options[count] = new Option(arCats[i], arCats[i]);
                    count ++;
                }
                SkillsPlugin.main.unlockForm();
            }

            SkillsPlugin.main.lockForm();
            _resetSkillDetails();
            SkillsPlugin.main.getCategories( fnCallback );
            elCatSelect.selectedIndex = 0;
            var elSkillSelect = document.getElementById(
                "addedit-skill-select");
            elSkillSelect.options[0] = new Option("Select a category above...", "0", true);
        },
        
        // populates the skill select menu
        populateSkills: function(){
            var elSkillSelect = document.getElementById(
                "addedit-skill-select");
            
            // get selected category (could be stored in global variable)?
            var elCatSelect = document.getElementById(
                "addedit-category-select");
            var catSelIndex = elCatSelect.selectedIndex;
            var cat = elCatSelect.options[catSelIndex].value;
            
            // ensure any previous skills are removed from options
            elSkillSelect.options.length = 0;
            
            if( cat == 0 ){
                elSkillSelect.options[0] = new Option("Select a category above...", "0", true);
                return;
            }
            
            elSkillSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arSkills ){
                elSkillSelect.options[0] = new Option("Select a skill...", "0", true);
                var count = 1;
                for( var i in arSkills ){
                    if(arSkills[i] == ''){
                        continue;
                    }
                    elSkillSelect.options[count] = new Option(arSkills[i], arSkills[i]);
                    count ++;
                }
                SkillsPlugin.main.unlockForm();
            }
            
            SkillsPlugin.main.lockForm();
            _resetSkillDetails();
            SkillsPlugin.main.getSkills( cat, fnCallback );
        },
        
        // populates the rating and the comment for a skill
        populateSkillDetails: function(){
            _resetSkillDetails();
            
            // get selected category and skill
            var elCatSelect = document.getElementById(
                "addedit-category-select");
            var catSelIndex = elCatSelect.selectedIndex;
            var cat = elCatSelect.options[catSelIndex].value;
            
            var elSkillSelect = document.getElementById(
                "addedit-skill-select");
            var skillSelIndex = elSkillSelect.selectedIndex;
            var skill = elSkillSelect.options[skillSelIndex].value;
            
            var fnCallback = function( skid ){
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
                    var elComment = document.getElementById(_idComment);
                    if (elComment != null)
                        elComment.value = skid.comment;
                    _showClearComment();
                }
                SkillsPlugin.main.unlockForm();
            }

            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.getSkillDetails( cat, skill, fnCallback );
        },
        
        // submits the form
        submit: function() {
            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.submit(
                'addEditSkill', "addedit-skill-form",
                "addedit-skills-message",
                _resetForm);
        },
        
        // clears the comment text field
        clearComment: function(){
            var elComment = document.getElementById(_idComment);
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
if( SkillsPlugin.vars.addEditSkills ){
    SkillsPlugin.addEditSkills.init();
}

SkillsPlugin.editAllSkills = function () {
    
    var
    _idSubmit       = "editall-skills-submit",
    _idMessageContainer = "editall-skills-message-container",
    _idMessage      = "editall-skills-message";
        
    return {

        init: function(){
            this.locked = false;

            // register events
            YAHOO.util.Event.onAvailable(
                "editall-tbody", this.populateTable,
                this, true);
            
            YAHOO.util.Event.addListener(
                _idSubmit, "click", this.submit, this, true);
        },
        
        populateTable: function(){
            var elCatTableTBody = document.getElementById(
                "editall-tbody");
            if (elCatTableTBody == null)
                return;

            if( SkillsPlugin.vars.loggedIn == 0 ){
                var tr = document.createElement('tr');
                tr.className = 'skillsCatTable_category';
                var td = document.createElement('td');
                td.className = "foswikiAlert";
                td.appendChild(
                    document.createTextNode("Please log in..."));
                tr.appendChild(td);
                elCatTableTBody.appendChild(tr);
                SkillsPlugin.main.lockForm();
                return;
            }
            
            // Clean out the category table. The ID points to the tbody,
            // so we can just vacuum that.
            while (elCatTableTBody.firstChild != null) {
                elCatTableTBody.removeChild(elCatTableTBody.firstChild);
            }
            
            var fnCallback = function( arCats ){
                for( var i in arCats ){
                    // Create a table row to contain the category and
                    // act as an anchor for the added entries
                    var tr = document.createElement('tr');
                    tr.className = 'skillsCatTable_category';
                    elCatTableTBody.appendChild(tr);
                    var th = document.createElement('th');
                    th.className = 'skillsCatTable_category';
                    th.colSpan = 8;
                    tr.appendChild(th);
                    th.appendChild(document.createTextNode(arCats[i]));

                    var id = 'editall.' + arCats[i];
                    tr.id = id;
                    SkillsPlugin.main.tipify(tr, arCats[i]);

                    var img = document.createElement('div');
                    img.className = 'skillsSpinner';
                    img.id = id + '_spinner';
                    th.appendChild(img);

                    // Now get the skills and add each as a row
                    SkillsPlugin.main.getSkillsAndDetails(
                        arCats[i],
                        function( data, cat ) {
                            var catid = 'editall.' + cat;
                            var reltotr = document.getElementById(catid);
                            var spinner = document.getElementById(
                                catid + "_spinner");
                            if (spinner != null)
                                spinner.parentNode.removeChild(spinner);
                            var skills = data[cat];
                            for( var skill in skills ) {
                                var skill_data = skills[skill];
                                var skid = catid + '.' + skill;
                                var tr = document.createElement('tr');
                                tr.className = "skillsCatTable_skill";
                                if (reltotr.nextSibling == null) {
                                    reltotr.parentNode.appendChild(tr);
                                } else {
                                    reltotr.parentNode.insertBefore(
                                        tr, reltotr.nextSibling);
                                }
                                tr.appendChild(document.createElement('td'));
                                var th = document.createElement('th');
                                th.className = "skillsCatTable_skill";
                                tr.appendChild(th);
                                th.appendChild(
                                    document.createTextNode(skill));
                                th.id = skid + 'th';
                                SkillsPlugin.main.tipify(th, cat, skill);
                                // Radio buttons for the priority
                                var prios = [ 1, 2, 3, 4, 0 ];
                                for (var k in prios) {
                                    var td = document.createElement('td');
                                    tr.appendChild(td);
                                    td.className = "skillsCatTable";
                                    var inp = document.createElement('input');
                                    inp.className = "skillsCatTable skillsRating skillsControl";
                                    td.appendChild(inp);
                                    inp.type = 'radio';
                                    inp.name = skid + "-rating";
                                    inp.id = skid + "-rating";
                                    inp.value = prios[k];
                                    if (skill_data.rating != null &&
                                        skill_data.rating == prios[k]) {
                                        inp.checked = "checked";
                                    }
                                    inp.onclick = function() {
                                        var elSubmit =
                                        document.getElementById(_idSubmit);
                                        elSubmit.className = "foswikiSubmit";
                                    };
                                }
                                var td = document.createElement('td');
                                tr.appendChild(td);
                                inp = document.createElement('input');
                                td.appendChild(inp);
                                inp.className = "skillsCatTable skillsComment skillsControl";
                                inp.type = 'text';
                                inp.name = skid + "-comment";
                                inp.id = skid + "-comment";
                                if (skill_data.comment != null) {
                                    inp.value = skill_data.comment;
                                }
                                YAHOO.util.Event.addListener(
                                    inp.id, "keyup",
                                    function() {
                                        var elSubmit =
                                            document.getElementById(_idSubmit);
                                        elSubmit.className = "foswikiSubmit";
                                    }, this, true);
                                inp.size = 15;
                            }
                            SkillsPlugin.main.genTips();
                        });
                }
                SkillsPlugin.main.unlockForm();
            };

            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.getCategories( fnCallback );
        },
        
        // submits the form
        submit: function() {
            SkillsPlugin.main.submit(
                'saveUserChanges', "editall-skills-form",
                "editall-skills-message");
        }
    };
    
}();
if( SkillsPlugin.vars.editAllSkills ){
    SkillsPlugin.editAllSkills.init();
}

SkillsPlugin.searchSkills = function () {
    
    // resets the entire form to its initial state
    var _resetForm = function(){
        var elSkillSelect = document.getElementById("search-skill-select");
        elSkillSelect.options.length = 0;
        SkillsPlugin.searchSkills.populateCategories();
    }
  
    var _populateResults = function( results ){
        var elResults = document.getElementById("search-skill-results");
        elResults.innerHTML = results;
    }
    
    return {
        
        init: function(){

            this.locked = false;

            // register events
            YAHOO.util.Event.onAvailable(
                "search-category-select", this.populateCategories, this, true);
            
            YAHOO.util.Event.addListener(
                "search-category-select", "change", this.populateSkills,
                this, true);
            
            YAHOO.util.Event.addListener(
                "search-skill-submit", "click", this.submit, this, true);
        },
        
        // populates the category select menu
        populateCategories: function(){
            var elCatSelect = document.getElementById(
                "search-category-select");
            elCatSelect.options.length = 0;
            
            if( SkillsPlugin.vars.loggedIn == 0 ){
                elCatSelect.options[0] = new Option(
                    "Please log in...", "0", true);
                SkillsPlugin.main.lockForm();
                return;
            }
            elCatSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arCats ){
                elCatSelect.options[0] = new Option(
                    "Select a category...", "0", true);
                var count = 1;
                for( var i in arCats ){
                    elCatSelect.options[count] =
                        new Option(arCats[i], arCats[i]);
                    count ++;
                }
                SkillsPlugin.main.unlockForm();
            }

            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.getCategories( fnCallback );
            elCatSelect.selectedIndex = 0;
            var elSkillSelect = document.getElementById(
                "search-skill-select");
            elSkillSelect.options[0] = new Option(
                "Select a category...", "0", true);
        },
        
        // populates the skill select menu
        populateSkills: function(){
            var elSkillSelect = document.getElementById("search-skill-select");
            
            // get selected category (could be stored in global variable)?
            var elCatSelect = document.getElementById(
                "search-category-select");
            var catSelIndex = elCatSelect.selectedIndex;
            var cat = elCatSelect.options[catSelIndex].value;
            
            // ensure any previous skills are removed from options
            elSkillSelect.options.length = 0;
            
            if( cat == 0 ){
                elSkillSelect.options[0] = new Option(
                    "Select a category...", "0", true);
                return;
            }
            
            elSkillSelect.options[0] = new Option("Loading...", "0", true);
            
            var fnCallback = function( arSkills ){
                elSkillSelect.options[0] = new Option(
                    "Select a skill...", "0", true);
                var count = 1;
                for( var i in arSkills ){
                    if(arSkills[i] == ''){
                        continue;
                    }
                    elSkillSelect.options[count] =
                        new Option(arSkills[i], arSkills[i]);
                    count ++;
                }
            }
            
            SkillsPlugin.main.getSkills( cat, fnCallback );
        },
        
        // submits the form
        submit: function(){
            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.submit(
                'search', "search-skill-form", "search-skills-message",
                function(o) {
                    _populateResults(o.responseText);
                });
        }
    };
    
}();

if( SkillsPlugin.vars.searchSkills ){
    SkillsPlugin.searchSkills.init();
}

SkillsPlugin.browseSkills = function () {
    
    return {
        
        init: function(){
            YAHOO.util.Event.onDOMReady(
                SkillsPlugin.main.initTwisty, this, true);
        }
    }
}();
if( SkillsPlugin.vars.browseSkills ){ 
    SkillsPlugin.browseSkills.init();
}
