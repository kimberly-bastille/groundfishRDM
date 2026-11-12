capture program drop confirm_prompt
program define confirm_prompt
    version 17.0
    args prompt_msg

    while 1 {
        display as input "`prompt_msg'  Do you want to proceed? (yes/no): " _request(_ans)
        
        if lower(trim("`ans'")) == "yes" {
            display as text "Proceeding..."
            continue, break
        }
        else if lower(trim("`ans'")) == "no" {
            display as error "Stopping execution."
			exit 1
        }
        else {
            display as error "Invalid input. Please type yes or no."
            continue
        }
    }
end
