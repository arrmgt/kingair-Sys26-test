function replace_string_with_number(dbfile, table, symbol, newVal, opts)
%REPLACE_STRING_WITH_NUMBER
% Replace one symbolic OutputRate value with a numeric value.
%
% Table schema:
%   [name   type   attribute   value]
%
% Example:
%   replace_string_with_number(X.varDB,'variables','CDPrate',10);

    %% Defaults
    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts,'dryRun'), opts.dryRun = true; end
    if ~isfield(opts,'verify'), opts.verify = true; end

    %% Escape single quotes for SQLite
    symbol_esc = strrep(symbol, '''', '''''');

    %% Open database
    db = sqlite(dbfile,'connect');

    try
        %% Dry-run
        if opts.dryRun
            sql = sprintf( ...
                "SELECT COUNT(*) FROM %s " + ...
                "WHERE attribute='OutputRate' AND value='%s'", ...
                table, symbol_esc);

            T = fetch(db, sql);
            count = T{1,1};

            fprintf('Dry-run: %d rows with OutputRate = "%s"\n', ...
                    count, symbol);
        end

        %% Update (INLINE values — no parameters)
        sql = sprintf( ...
            "UPDATE %s SET value=%d " + ...
            "WHERE attribute='OutputRate' AND value='%s'", ...
            table, newVal, symbol_esc);

        exec(db, sql);

        %% Rows changed
        T = fetch(db, 'SELECT changes()');
        nChanged = T{1,1};

        fprintf('Updated : %d rows  (%s → %d)\n', ...
                nChanged, symbol, newVal);

        %% Verify
        if opts.verify
            sql = sprintf( ...
                "SELECT DISTINCT value, typeof(value) FROM %s " + ...
                "WHERE attribute='OutputRate'", ...
                table);

            disp(fetch(db, sql));
        end

    catch ME
        close(db);
        rethrow(ME);
    end

    close(db);
end
