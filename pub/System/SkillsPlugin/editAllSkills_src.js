SkillsPlugin.editAllSkills = function () {
    var catTableTBody;

    // Create a table row introducing a category
    var createCategory = function(node, depth, context, count) {
        var subcontext =
        context.length ? context + '/' + node.name : node.name;

        var id = SkillsPlugin.main.makeID(subcontext);

        // Create a table row to contain the category and
        // act as an anchor for the added entries
        var tr = document.createElement('tr');
        tr.id = id;

        SkillsPlugin.main.tipify(tr);
            
        var th = document.createElement('th');
        th.colSpan = 4;
        var yth = new YAHOO.util.Element(th);
        yth.addClass('indent-category' + depth);
        yth.addClass('skillsplugin_category');
        
        //for (var i = 0; i < depth - 1; i++)
        //    th.appendChild(SkillsPlugin.main.createLineImg('ud'));
        //if (depth) {
        //    if (count)
        //        th.appendChild(SkillsPlugin.main.createLineImg('udr'));
        //    else
        //        th.appendChild(SkillsPlugin.main.createLineImg('ur'));
        //}

        th.appendChild(document.createTextNode(node.name));

        tr.appendChild(th);

        catTableTBody.appendChild(tr);

        return subcontext;
    };

    // Create a radio button for ratings
    var createRatingRadio = function(tr, idx, node, skid) {
        var td = document.createElement('td');
        var ytd = new YAHOO.util.Element(td);
        tr.appendChild(td);
        ytd.addClass("skillsForm");
        ytd.addClass("skillsFormRatingCell");

        var inp;
        if (YAHOO.env.ua.ie > 0) {
            // bloody IE crap
            inp = document.createElement(
                '<input type="radio" name="' + skid
                + '-rating" id="' + skid + '-rating-' + idx
                + '" value="' + idx + '">');
        } else {
            var inp = document.createElement('input');
            inp.type = 'radio';
            inp.name = skid + "-rating";
            inp.id = skid + "-rating-" + idx;
            inp.value = idx;
        }

        var yinp = new YAHOO.util.Element(inp);
        yinp.addClass("skillsFormRatingControl");
        yinp.addClass("skillsFormControl");
        td.appendChild(inp);
        if (node.rating != null && node.rating == idx) {
            inp.checked = "checked";
        }
        inp.onclick = function() {
            var elSubmit = document.getElementById("editall-skills-submit");
            var yelSubmit = new YAHOO.util.Element(elSubmit);
            yelSubmit.addClass("foswikiSubmit");
        };
    };

    // Create a table row for a skill
    var createSkillNode = function(node, depth, context, count) {
        var subcontext = context.length ?
        context + '/' + node.name : node.name;
        var skid = SkillsPlugin.main.makeID(subcontext);

        var tr = document.createElement('tr');
        tr.id = skid;

        catTableTBody.appendChild(tr);

        var cat = document.createElement('td');
        tr.appendChild(cat);

        var th = document.createElement('th');
        var yth = new YAHOO.util.Element(th);
        yth.addClass("skillsplugin_skill");
        th.appendChild(document.createTextNode(node.name));
        th.id = skid + 'th';
        tr.appendChild(th);

        SkillsPlugin.main.tipify(tr);

        // Radio buttons for the priority
        var prios = [ 0, 1, 2, 3, 4 ];
        for (var k = 0; k < 5; k++) {
            createRatingRadio(tr, k, node, skid);
        }

        var td = document.createElement('td');
        var ytd = new YAHOO.util.Element(td);
        tr.appendChild(td);
        inp = document.createElement('input');
        yinp = new YAHOO.util.Element(inp);
        td.appendChild(inp);
        yinp.addClass("skillsFormCommentControl");
        yinp.addClass("skillsFormControl");
        inp.type = 'text';
        inp.name = skid + "-comment";
        inp.id = skid + "-comment";
        if (node.text != null) {
            inp.value = node.text;
        }
        YAHOO.util.Event.addListener(
            inp.id, "keyup",
            function() {
                var elSubmit = document.getElementById(
                    "editall-skills-submit");
                var yel = new YAHOO.util.Element(elSubmit);
                yel.addClass("foswikiSubmit");
            }, this, true);
        inp.size = 15;
    };

    var createNode = function(node, depth, context, countdown) {
        var count = node.childNodes.length;
        if (count > 0) {
            var subcontext = createCategory(node, depth, context, countdown);
            for (var i in node.childNodes) {
                var child = node.childNodes[i];
                createNode(child, depth + 1, subcontext, --count);
            }
        } else {
            createSkillNode(node, depth, context, 0);
        }
    }

    var cbSkillTree = function( tree ){
        catTableTBody = document.getElementById("editall-tbody");
        for (var i in tree.childNodes) {
            createNode(tree.childNodes[i], 0, '', 0);
        }
        SkillsPlugin.main.unlockForm();
        SkillsPlugin.main.createTooltips();
    };

    return {
        populateTable: function(){
            var catTableTBody = document.getElementById("editall-tbody");
            if( SkillsPlugin.vars.loggedIn == 0 ){
                var tr =
                    document.createElement('tr');
                var ytr = new YAHOO.util.Element(tr);
                ytr.addClass('skillsplugin_category');
                var td =
                    document.createElement('td');
                var ytd = new YAHOO.util.Element(td);
                ytd.addClass(td, "foswikiAlert");
                td.colSpan = 4;
                td.appendChild(
                    document.createTextNode("Please log in..."));
                tr.appendChild(td);
                catTableTBody.appendChild(tr);
                SkillsPlugin.main.lockForm();
                return;
            }
            
            // Clean out the category table. The ID points to the tbody,
            // so we can just vacuum that.
            while (catTableTBody.firstChild != null) {
                catTableTBody.removeChild(catTableTBody.firstChild);
            }
            
            SkillsPlugin.main.lockForm();
            SkillsPlugin.main.get('getSkillTree', cbSkillTree);
        },
        
        // submits the form
        submit: function() {
            SkillsPlugin.main.submit(
                'saveUserChanges', "editall-skills-form",
                function (o) {
                    SkillsPlugin.main.displayMessage(
                        o.responseText, "editall-skills-message");
                });
        }
    };
    
}();

// register events
YAHOO.util.Event.onAvailable(
    "editall-tbody",
    SkillsPlugin.editAllSkills.populateTable,
    SkillsPlugin.editAllSkills, true);
            
YAHOO.util.Event.addListener(
    "editall-skills-submit", "click",
    SkillsPlugin.editAllSkills.submit,
    SkillsPlugin.editAllSkills, true);
