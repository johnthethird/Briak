/***********************************************************/
/*                    LiveFilter Plugin                    */
/*                      Version: 1.0.1                     */
/*                      Mike Merritt                       */
/*                 Updated May 15th, 2009                  */
/***********************************************************/

(function($){  
	$.fn.liveFilter = function (list) {
		// Grabs the id of the element containing the filter
		var wrap = '#' + $(this).attr('id');
		
		// Listen for the value of the input to change
		$('input.filter').keyup(function() {
			
			// Grab the current value of the filter
			var filter = $(this).val();
			
			
			// Hide all elements that do not contain the filter string
			$(wrap + ' ' + list + ' li:not(:Contains("' + filter + '"))').hide();

			// Show already hidden elements that do contain the filter string
			$(wrap + ' ' + list + '  li:Contains("' + filter + '")').show();
		
		});
		
		jQuery.expr[':'].Contains = function(a,i,m){
		    return jQuery(a).text().toUpperCase().indexOf(m[3].toUpperCase())>=0;
		};

		
	}

})(jQuery);